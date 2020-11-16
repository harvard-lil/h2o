import requests
import json

from django.conf import settings
from django.core.paginator import Paginator
from django.shortcuts import render
from django.urls import reverse

from rest_framework.response import Response
from rest_framework import status
from rest_framework.decorators import api_view, renderer_classes
from rest_framework.renderers import JSONRenderer


from test.test_helpers import check_response
from main.utils import looks_like_citation,looks_like_case_law_link
from .models import SearchIndex
from search.utils import hybrid_search

import logging
logger = logging.getLogger('django')

type_param_to_category = {'cases': 'case', 'casebooks': 'casebook', 'users': 'user'}


def search(request):
    """
        Search page.

        Given:
        >>> capapi_mock, client, casebook_factory = [getfixture(i) for i in ['capapi_mock', 'client', 'casebook_factory']]
        >>> casebooks = [casebook_factory(contentcollaborator_set__user__verified_professor=True) for i in range(3)]
        >>> url = reverse('search')
        >>> SearchIndex().create_search_index()

        Show all casebooks by default:
        >>> check_response(client.get(url), content_includes=[c.title for c in casebooks])

        See SearchIndex._search tests for more specific tests.

        This view is also used for searching by citation for cases to import from CAPAPI. The CAP version kicks in if
        we provide 'type': 'cases', 'partial': 'true', and a query that starts and ends in digits:
        >>> check_response(
        ...     client.get(url, {'type': 'cases', 'q': '722 F.3d 1229', 'partial': 'true'}),
        ...     content_includes=['data-result-id="1" data-result-type="capapi/case"', '1-800 Contacts, Inc. v. Lens.Com, Inc.'],
        ... )
    """
    # read query parameters
    category = type_param_to_category.get(request.GET.get('type', None), 'casebook')
    try:
        page = int(request.GET.get('page'))
    except (TypeError, ValueError):
        page = 1
    query = request.GET.get('q')
    partial = request.GET.get('partial') == 'true'

    # query CAP API if we are searching for a citation from the add-resource modal:
    if category == 'case' and partial and looks_like_citation(query):
        response = requests.get(settings.CAPAPI_BASE_URL + "cases/", {"cite": query})
        results = response.json()['results']
        results = Paginator(results, 10).get_page(1)
        results.from_capapi = True
        counts = facets = None

    # else query postgres:
    else:
        filters = {}
        author = request.GET.get('author')
        school = request.GET.get('school')
        if author:
            filters['attribution'] = author
        if school:
            filters['affiliation'] = school

        results, counts, facets = SearchIndex.search(
            category,
            page=page,
            query=query,
            filters=filters,
            facet_fields=['attribution', 'affiliation'],
            order_by=request.GET.get('sort')
        )
        results.from_capapi = False

    if partial:
        return render(request, 'search/results.html', {
            'results': results,
            'category': category,
            'path': reverse('search'),
        })
    else:
        return render(request, 'search/show.html', {
            'results': results,
            'counts': counts,
            'facets': facets,
            'category': category,
        })


@api_view(('GET',))
@renderer_classes((JSONRenderer,))
def search_cases(request):
    query = request.GET.get('q')
    search_params = {k: request.GET.get(k) for k in request.GET.keys() if k != 'q'}
    frontend_url = None
    if not query:
        return Response('', status=status.HTTP_400_BAD_REQUEST)
    query = query.replace('’',"'")
    if looks_like_case_law_link(query):
        frontend_url = query.split('cite.case.law')[1]
        search_params['search'] = 'frontend_url:"{}"'.format(frontend_url)
    elif looks_like_citation(query):
        search_params['citation'] = query
    else:
        search_params['name'] = query
    results = hybrid_search(search_params)
    if frontend_url and len(results) > 0:
        results['results'] = [x for x in results['results'] if x.get('frontend_url','cite.case.law').split('cite.case.law')[-1] == frontend_url]
    if results['via'] == 'hybrid' or results['via'] == 'CL':
        logger.info("CASE_SEARCH: params=%s, in_cap=%s", json.dumps(search_params), results['via'] == 'hybrid')
    return Response(results, status=200)
