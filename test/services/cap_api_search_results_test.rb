require 'application_system_test_case'

class CapApiSearchResultsTest < ServiceTestCase
  scenario 'returns an array of cases' do 
    search_params = { name: 'Comer v. Titan Tool, Inc.', citation: '875 F. Supp. 255' }

    stub_case_search(search_params)
    results = CapApiSearchResults.perform(search_params)

    assert_equal results, search_result
  end

  scenario 'returns empty array if cap api call fails' do
    search_params = { name: 'not a case', citation: 'invalid citation' }

    stub_case_search_with_no_results(search_params)
    results = CapApiSearchResults.perform(search_params)

    assert_equal results, []
  end
end
