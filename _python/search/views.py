from django.shortcuts import render

from .models import SearchIndex

type_param_to_category = {'cases': 'case', 'casebooks': 'casebook', 'users': 'user'}

def search(request):
    category = type_param_to_category.get(request.GET.get('type', None), 'casebook')
    results, counts, facets = SearchIndex.search(category)
    return render(request, 'search/show.html', {
        'results': results,
        'counts': counts,
        'facets': facets,
        'category': category,
    })