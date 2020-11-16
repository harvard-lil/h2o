from django.conf import settings
from django.urls import reverse
from search.models import SearchIndex
from main.models import Case

import requests

# Search params: name, citation, full_text, after_date, before_date


def normalize_dictionary(remap_map, params):
    return {remap_map[k]: params[k] for k in remap_map.keys() if k in params}


def cap_search(params, limit=10):
    param_normalizer = {'name': 'name_abbreviation',
                        'citation': 'cite',
                        'full_text': 'search',
                        'before_date': 'decision_date_max',
                        'after_date': 'decision_date_min',
                        'jurisdiction': 'jurisdiction',
                        'search':'search'}
    param_defaults = {'page_size': limit, 'ordering': '-analysis.pagerank.percentile'}
    # In some cases, cap search will return too many results for what should be a unique search by frontend_urls
    if 'frontend_url' in params.get('search', ''):
        param_defaults.pop('ordering')
    search_params = {**param_defaults, **normalize_dictionary(param_normalizer, params)}
    response = requests.get(settings.CAPAPI_BASE_URL + "cases/", search_params)
    try:
        results = response.json()['results']
    except Exception:
        results = None
    return results


def courtlistener_search(params, limit=10):
    param_normalizer = {'name': 'case_name',
                        'citation': 'citation',
                        'full_text': 'q',
                        'before_date': 'filed_before',
                        'after_date': 'filed_after'}
    param_defaults = {'order_by': 'score desc', 'stat_Precedential': 'on'}
    normalized_params = normalize_dictionary(param_normalizer, params)
    search_params = {**param_defaults, **normalized_params}

    if not normalized_params:
        return []

    def normalize_results(results_json):
        result_normalizer = {'caseName': 'name', 'caseNameShort': 'name_abbreviation', 'dateFiled': 'decision_date', 'docketNumber': 'docket_number', 'citation': 'citations'}
        results = []
        for r in results_json:
            n = normalize_dictionary(result_normalizer, r)
            court_name = n.get('court', None)
            n['court'] = {'court_name': court_name}
            if 'citations' in n and n['citations']:
                n['citations'] = [{'type': 'unknown', 'cite': x} for x in n.get('citations', [])]
            results.append(n)
        return results

    extra_args = {}
    if settings.COURTLISTENER_KEY:
        extra_args['headers'] = {'Authorization': 'Token %s' % settings.COURTLISTENER_KEY}
    try:
        response = requests.get(settings.COURTLISTENER_BASE_URL + "api/rest/v3/search/", search_params, **extra_args)
        data = response.json()
        if 'results' not in data:
            return []
        results = normalize_results(data['results'][0:limit])
        return results
    except Exception:
        return []

def internal_case_search(params, limit=10):
    name = params.get('name', None)
    filter_normalizer = {'citation': 'citations__contains',
                         'before_date': 'decision_date__lte',
                         'after_date': 'decision_date__gte',
                         'jurisdiction':'jurisdiction'}
    normalized_filters = normalize_dictionary(filter_normalizer, params)
    res, _, _ = SearchIndex.search('case', name, filters=normalized_filters)
    case_ids = [x.result_id for x in res.object_list]
    internal_cases = {x.id: x for x in Case.objects.filter(id__in=case_ids).all()}
    normalized_results = []
    for case in res.object_list:
        current = {}
        current['name'] = case.metadata['display_name']
        cites = case.metadata.get('citations', '')
        current['citations'] = [{'type':'unknown', 'cite': c} for c in cites.split(', ')] if cites else []
        current['decision_date'] = case.metadata['decision_date']
        current['jurisdiction'] = ''
        current['capapi_id'] = internal_cases[case.result_id].capapi_id if case.result_id in internal_cases else None
        current['frontend_url'] = reverse('case', args=[case.result_id])
        current['h2o_case_id'] = case.result_id
        normalized_results.append(current)
    return normalized_results



def hybrid_search(params, limit=10):
    internal_results = internal_case_search(params)
    cap_results = cap_search(params, limit)
    if cap_results:
        found_in_cap = {r['id'] for r in cap_results}
        merged_results = cap_results + [r for r in internal_results if r['capapi_id'] not in found_in_cap]
        return {'results': merged_results, 'via': 'CAP'}
    elif internal_results:
        return {'results': internal_results, 'via': 'H2O'}
    cl_results = courtlistener_search(params, limit)
    if not cl_results:
        return {'results': [], 'via': 'both'}
    if 'citations' in cl_results[0] and cl_results[0]['citations']:
        for citation in cl_results[0]['citations'][0:3]:
            cap_results = cap_search({'citation': citation['cite']})
            if cap_results:
                return {'results': cap_results, 'via': 'hybrid'}
    return {'results': [], 'via': 'CL'}
