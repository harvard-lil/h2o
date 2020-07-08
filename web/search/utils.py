from django.conf import settings

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
                        'jurisdiction': 'jurisdiction'}
    param_defaults = {'page_size': limit, 'ordering': 'relevance'}
    search_params = {**param_defaults, **normalize_dictionary(param_normalizer, params)}
    response = requests.get(settings.CAPAPI_BASE_URL + "cases/", search_params)
    try:
        results = response.json()['results']
    except Exception:
        results = None
    return results


def courtlistener_search(params, limit=10):
    param_normalizer = {'name': 'case_name', 'citation': 'citation', 'full_text': 'q', 'before_date': 'filed_before', 'after_date': 'filed_after'}
    param_defaults = {'order_by': 'score desc', 'stat_Precedential': 'on'}
    search_params = {**param_defaults, **normalize_dictionary(param_normalizer, params)}

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
    response = requests.get(settings.COURTLISTENER_BASE_URL + "api/rest/v3/search/", search_params, **extra_args)
    data = response.json()
    if 'results' not in data:
        return []
    results = normalize_results(data['results'][0:limit])

    return results


def hybrid_search(params, limit=10):
    cap_results = cap_search(params, limit)
    if cap_results:
        return {'results': cap_results, 'via': 'CAP'}
    cl_results = courtlistener_search(params, limit)
    if not cl_results:
        return {'results': [], 'via': 'both'}
    if 'citations' in cl_results[0] and cl_results[0]['citations']:
        for citation in cl_results[0]['citations'][0:3]:
            cap_results = cap_search({'citation': citation['cite']})
            if cap_results:
                return {'results': cap_results, 'via': 'hybrid'}
    return {'results': [], 'via': 'CL'}
