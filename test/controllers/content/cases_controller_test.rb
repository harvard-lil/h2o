# coding: utf-8
require 'test_helper'

class CasesControllerTest < ActionDispatch::IntegrationTest
  describe Content::CasesController, :from_capapi do
    it "should return a 400 when the id param is missing" do
      post "/cases/from_capapi"
      assert_response :bad_request
      assert_equal({"id" => "is required"}, response.parsed_body)
    end

    it "should create a new case when the capapi id doesn't already exist" do
      capapi_id = 2747110
      refute Case.find_by(capapi_id: capapi_id)

      raw_response_file = File.new("#{Rails.root}/test/stubs/capapi.org-api-v1–cases-#{capapi_id}.txt")
      stub_request(:get, /api.case.law/).to_return(raw_response_file)

      post "/cases/from_capapi", params: {id: capapi_id}
      assert_response :success
      c = Case.find_by(capapi_id: capapi_id)
      assert_equal({"id" => c.id}, response.parsed_body)
    end

    it "should return the case id when a case with the specified capapi_id already exist" do
      c = cases(:case_with_capapi_id)
      post "/cases/from_capapi", params: {id: c.capapi_id}
      assert_response :success
      assert_equal({"id" => c.id}, response.parsed_body)
    end
  end
end
