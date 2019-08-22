from pathlib import Path

from django.contrib.postgres.fields import JSONField
from django.contrib.postgres.search import SearchVectorField, SearchRank
from django.core.paginator import Paginator
from django.db import models, connection, ProgrammingError
from django.db.models import Count, F

def get_display_name_field(category):
    display_name_fields = {
        'case': 'display_name',
        'casebook': 'title',
        'user': 'attribution'
    }
    return 'metadata__%s' % display_name_fields[category]

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
        with connection.cursor() as cursor:
            cursor.execute(Path(__file__).parent.joinpath('create_search_index.sql').read_text())

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
        base_query = cls.objects.all()
        if query:
            base_query = base_query.filter(document=query)
        for k, v in filters.items():
            base_query = base_query.filter(**{'metadata__%s' % k: v})

        # get results
        results = base_query.filter(category=category).only('result_id', 'metadata')
        if query:
            results = results.annotate(rank=SearchRank(F('document'), query))

        display_name = get_display_name_field(category)
        order_by_expression = [display_name]
        if order_by:
            # Treat 'decision date' like 'created at', so that sort-by-date is maintained
            # when switching between case and casebook tab.
            # Later, let's consider renaming these params "date".
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
