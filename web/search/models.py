from pathlib import Path

from django.contrib.postgres.fields import JSONField
from django.contrib.postgres.search import SearchVectorField, SearchRank, SearchQuery
from django.core.paginator import Paginator
from django.db import models, connection, ProgrammingError
from django.db.models import Count, F

from main.utils import fix_after_rails


def get_display_name_field(category):
    display_name_fields = {
        'case': 'display_name',
        'casebook': 'title',
        'user': 'attribution'
    }
    return 'metadata__%s' % display_name_fields[category]


def dump_search_results(parts):
    results, counts, facets = parts
    return ([{k: '...' if k == 'created_at' else v for k, v in r.metadata.items()} for r in results.object_list], counts, facets)


class SearchIndex(models.Model):
    result_id = models.IntegerField()
    document = SearchVectorField()
    metadata = JSONField()
    category = models.CharField(max_length=255)

    class Meta:
        managed = False
        db_table = 'search_view'

    @classmethod
    def create_search_index(cls):
        """ Create or replace the materialized view 'search_view', which backs this model """
        with connection.cursor() as cursor:
            cursor.execute(Path(__file__).parent.joinpath('create_search_index.sql').read_text())

    @classmethod
    def refresh_search_index(cls):
        """ Refresh the contents of the materialized view """
        with connection.cursor() as cursor:
            try:
                cursor.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY search_view")
            except ProgrammingError as e:
                if e.args[0].startswith('relation "search_view" does not exist'):
                    cls.create_search_index()

    @classmethod
    def search(cls, *args, **kwargs):
        try:
            return cls._search(*args, **kwargs)
        except ProgrammingError as e:
            if e.args[0].startswith('relation "search_view" does not exist'):
                cls.create_search_index()
                return cls._search(*args, **kwargs)
            raise

    @classmethod
    def _search(cls, category, query=None, page_size=10, page=1, filters={}, facet_fields=[], order_by=None):
        """
        Given:
        >>> _, case_factory, casebook_factory = [getfixture(i) for i in ['reset_sequences', 'case_factory', 'casebook_factory']]
        >>> casebooks = [casebook_factory() for i in range(3)]
        >>> users = [cc.user for cb in casebooks for cc in cb.contentcollaborator_set.all() ]
        >>> cases = [case_factory() for i in range(3)]
        >>> SearchIndex().create_search_index()

        Get all casebooks:
        >>> assert dump_search_results(SearchIndex().search('casebook')) == (
        ...     [
        ...         {'affiliation': 'Affiliation 0', 'created_at': '...', 'title': 'Some Title 0', 'attribution': 'Some User 0'},
        ...         {'affiliation': 'Affiliation 1', 'created_at': '...', 'title': 'Some Title 1', 'attribution': 'Some User 1'},
        ...         {'affiliation': 'Affiliation 2', 'created_at': '...', 'title': 'Some Title 2', 'attribution': 'Some User 2'}
        ...     ],
        ...     {'user': 3, 'case': 3, 'casebook': 3},
        ...     {}
        ... )

        Get casebooks by query string:
        >>> assert dump_search_results(SearchIndex().search('casebook', 'Some Title 0'))[0] == [
        ...     {'affiliation': 'Affiliation 0', 'created_at': '...', 'title': 'Some Title 0', 'attribution': 'Some User 0'},
        ... ]

        Get casebooks by filter field:
        >>> assert dump_search_results(SearchIndex().search('casebook', filters={'attribution': 'Some User 1'}))[0] == [
        ...     {'affiliation': 'Affiliation 1', 'created_at': '...', 'title': 'Some Title 1', 'attribution': 'Some User 1'},
        ... ]

        Get all users:
        >>> assert dump_search_results(SearchIndex().search('user')) == (
        ...     [
        ...         {'casebook_count': 1, 'attribution': 'Some User 0', 'affiliation': 'Affiliation 0'},
        ...         {'casebook_count': 1, 'attribution': 'Some User 1', 'affiliation': 'Affiliation 1'},
        ...         {'casebook_count': 1, 'attribution': 'Some User 2', 'affiliation': 'Affiliation 2'},
        ...     ],
        ...     {'casebook': 3, 'case': 3, 'user': 3},
        ...     {},
        ... )

        Get all cases:
        >>> assert dump_search_results(SearchIndex().search('case')) == (
        ...     [
        ...         {'citations': '1 Mass. 1, 2 Jones 2', 'display_name': 'Foo0 v. Bar0', 'decision_date': '1900-01-01', 'decision_date_formatted': 'January   1, 1900'},
        ...         {'citations': '1 Mass. 1, 2 Jones 2', 'display_name': 'Foo1 v. Bar1', 'decision_date': '1900-01-01', 'decision_date_formatted': 'January   1, 1900'},
        ...         {'citations': '1 Mass. 1, 2 Jones 2', 'display_name': 'Foo2 v. Bar2', 'decision_date': '1900-01-01', 'decision_date_formatted': 'January   1, 1900'}
        ...     ],
        ...     {'case': 3, 'user': 3, 'casebook': 3},
        ...     {}
        ... )
        """
        base_query = cls.objects.all()
        query_vector = SearchQuery(query, config='english') if query else None
        if query_vector:
            base_query = base_query.filter(document=query_vector)
        for k, v in filters.items():
            base_query = base_query.filter(**{'metadata__%s' % k: v})

        # get results
        results = base_query.filter(category=category).only('result_id', 'metadata')
        if query_vector:
            results = results.annotate(rank=SearchRank(F('document'), query_vector))

        display_name = get_display_name_field(category)
        order_by_expression = [display_name]
        if order_by:
            # Treat 'decision date' like 'created at', so that sort-by-date is maintained
            # when switching between case and casebook tab.
            fix_after_rails('consider renaming these params "date".')
            if query and order_by == 'score':
                order_by_expression = ['-rank', display_name]
            elif category == 'casebook':
                if order_by in ['created_at', 'decision_date']:
                    order_by_expression = ['-metadata__created_at', display_name]
            elif category == 'case':
                if order_by in ['created_at', 'decision_date']:
                    order_by_expression = ['-metadata__decision_date', display_name]

        results = results.order_by(*order_by_expression)
        results = Paginator(results, page_size).get_page(page)

        # get counts
        counts = {c['category']: c['total'] for c in base_query.values('category').annotate(total=Count('category'))}
        results.__dict__['count'] = counts.get(category, 0)  # hack to avoid redundant query for count

        # get facets
        facets = {}
        for facet in facet_fields:
            facet_param = 'metadata__%s' % facet
            facets[facet] = base_query.filter(category=category).exclude(**{facet_param: ''}).order_by(facet_param).values_list(facet_param, flat=True).distinct()

        return results, counts, facets
