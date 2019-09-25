from django.shortcuts import render

from .models import SearchIndex

type_param_to_category = {'cases': 'case', 'casebooks': 'casebook', 'users': 'user'}


def search(request):
    category = type_param_to_category.get(request.GET.get('type', None), 'casebook')
    try:
        page = int(request.GET.get('page'))
    except (TypeError, ValueError):
        page = 1

    filters = {}
    author = request.GET.get('author')
    school = request.GET.get('school')
    if author:
        filters['attribution']= author
    if school:
        filters['affiliation']= school

    results, counts, facets = SearchIndex.search(
        category,
        page=page,
        query=request.GET.get('q'),
        filters=filters,
        facet_fields=['attribution', 'affiliation'],
        order_by=request.GET.get('sort')
    )
    return render(request, 'search/show.html', {
        'results': results,
        'counts': counts,
        'facets': facets,
        'category': category,
    })
