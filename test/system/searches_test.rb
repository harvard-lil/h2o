# coding: utf-8
require 'application_system_test_case'

class SearchesSystemTest < ApplicationSystemTestCase
  scenario 'searching cases paginates the results', solr: true do
    visit search_path(type: 'cases')
    id = first('a[data-result-id]')['data-result-id']
    assert id
    find('.next_page').click
    assert id != first('a[data-result-id]')['data-result-id'],
           "The next page didn't have a different results set"
  end

  scenario 'searching capapi cases paginates the results', solr: true do
    WebMock.disable_net_connect!(allow_localhost: true)
    
    cite = '1-ill-19'
    query = {"cite" => cite,
             "limit" => SearchesController::PER_PAGE}

    resp = File.new("#{Rails.root}/test/stubs/capapi.org-api-v1–cases.txt")
    stub_request(:get, "https://api.case.law/v1/cases/")
      .with(query: query.merge(offset: 0))
      .to_return(resp)

    resp = File.new("#{Rails.root}/test/stubs/capapi.org-api-v1–cases-offset-10.txt")
    stub_request(:get, "https://api.case.law/v1/cases/")
      .with(query: query.merge(offset: SearchesController::PER_PAGE))
      .to_return(resp)

    visit search_path(type: 'cases', q: cite, partial: true)
    id = first('a[data-result-id]')['data-result-id']
    assert id
    find('.next_page').click
    assert id != first('a[data-result-id]')['data-result-id'],
           "The next page didn't have a different results set"
  end
end
