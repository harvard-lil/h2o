# coding: utf-8
require 'test_helper'

class SearchesControllerTest < ActionDispatch::IntegrationTest
  describe SearchesController, :citation? do
    it "should match regular and slug citation forms" do
      ctrl = SearchesController.new
      assert ctrl.send(:citation?, "42 F. Supp. 135")
      assert ctrl.send(:citation?, "42-f-supp-135")
      refute ctrl.send(:citation?, "BOYER v. MILLER HATCHERIES, Inc.")
      refute ctrl.send(:citation?, "Not 42 F. Supp. 135")
      refute ctrl.send(:citation?, "42 F. Supp. 135 but not")
    end
  end

  describe SearchesController, :show do
    it "should query capapi for cases when the query string is a citation" do
      cite = cases(:case_with_citation).citations[0]["cite"]
      query = {"cite" => cite,
               "limit" => SearchesController::PER_PAGE,
               "offset" => 0}
      capapi_url = "https://api.case.law/v1/cases/"

      raw_response_file = File.new("#{Rails.root}/test/stubs/capapi.org-api-v1–cases-cite-275-us-303.txt")
      stub_request(:get, capapi_url)
        .with(query: query)
        .to_return(raw_response_file)

      get "/search", params: {type: "cases", q: cite, partial: true}
      assert_requested :get, capapi_url, query: query
    end

    it "should not query capapi for cases when the query string is not a citation" do
      q = "not a cite"
      query = {"cite" => q,
               "limit" => SearchesController::PER_PAGE,
               "offset" => 0}
      get "/search", params: {type: "cases", q: q, partial: true}
      assert_not_requested :get, "https://api.case.law/v1/cases/", query: query
    end

    it "should not query capapi for cases when searching outside of the add resources modal" do
      cite = cases(:case_with_citation).citations[0]["cite"]
      query = {"cite" => cite,
               "limit" => SearchesController::PER_PAGE,
               "offset" => 0}
      get "/search", params: {type: "cases", q: cite}
      assert_not_requested :get, "https://api.case.law/v1/cases/", query: query
    end
  end
end
