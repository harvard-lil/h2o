from pathlib import Path

from django.contrib.postgres.fields import JSONField
from django.contrib.postgres.search import SearchVectorField, SearchRank
from django.core.paginator import Paginator
from django.db import models, connection, ProgrammingError
from django.db.models import Count, F


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
    def _search(cls, category, query=None, page_size=10, page=1, filters={}, facet_fields=[]):
        base_query = cls.objects.all()
        if query:
            base_query = base_query.filter(document=query)
        for k, v in filters:
            base_query = base_query.filter(**{'metadata__%s' % k: v})

        # get results
        results = base_query.filter(category=category).only('result_id', 'metadata')
        if query:
            results = results.annotate(rank=SearchRank(F('document'), query)).order_by('-rank', 'result_id')
        results = Paginator(results, page_size).get_page(page)

        # get counts
        counts = {c['category']: c['total'] for c in base_query.values('category').annotate(total=Count('category'))}
        results.__dict__['count'] = counts[category]  # hack to avoid redundant query for count

        # get facets
        facets = {}
        for facet in facet_fields:
            facet_param = 'metadata__%s' % facet
            facets[facet] = [f[facet_param] for f in base_query.filter(category=category).values(facet_param).distinct()]

        return results, counts, facets
