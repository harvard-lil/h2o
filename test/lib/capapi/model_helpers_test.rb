# coding: utf-8
require 'test_helper'

class ModelHelpersTest < ActiveSupport::TestCase
  describe Capapi::ModelHelpers, :to_attributes do
    it "should parse out attorneys from the casebody html" do
      assert_equal ["John D. Shulleriberger, Morton Zwick, Director of Defender Project, of Chicago, (Matthew J. Moran, and Norman W. Fishman, of Defender Project, of counsel,) for appellant.",
                    "Robert H. Rice, State’s Attorney, of Belleville, for the People."],
                   Capapi::ModelHelpers.to_attributes(capapi_case)[:attorneys]
    end

    it "should parse out parties from the casebody html" do
      assert_equal ["The People of the State of Illinois, Plaintiff-Appellee, v. Danny Tobin, Defendant-Appellant."],
                   Capapi::ModelHelpers.to_attributes(capapi_case)[:parties]
    end

    it "should parse out opinions from the casebody html" do
      assert_equal [{"majority" => "Mr. PRESIDING JUSTICE EBERSPACHER"}],
                   Capapi::ModelHelpers.to_attributes(capapi_case)[:opinions]
    end
  end

  def capapi_case
    capapi_id = 2747110
    raw_response_file = File.new("#{Rails.root}/test/stubs/capapi.org-api-v1–cases-#{capapi_id}.txt")
    stub_request(:get, /api.case.law/).to_return(raw_response_file)
    Capapi::Case.retrieve({id: capapi_id, full_case: "true", body_format: "html"})
  end
end
