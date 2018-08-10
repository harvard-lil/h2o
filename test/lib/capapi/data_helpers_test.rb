require 'test_helper'

class DataHelpersTest < ActiveSupport::TestCase
  describe Capapi::DataHelpers, :parse_date do
    it "should parse year-only dates" do
      year = 2017
      assert_equal Date.new(year),
                   Capapi::DataHelpers.parse_date("#{year}")
    end

    it "should parse dates without a day specified" do
      year = 2017
      month = 11
      assert_equal Date.new(year, month, 1),
                   Capapi::DataHelpers.parse_date("#{year}-#{month}")
    end

    it "should handle dates with year, month, day" do
      year = 2017
      month = 11
      day = 20
      assert_equal Date.new(year, month, day),
                   Capapi::DataHelpers.parse_date("#{year}-#{month}-#{day}")
    end

    it "should handle dates with impossible month" do
      year = 2017
      month = 13
      assert_equal Date.new(year, month, 1),
                   Capapi::DataHelpers.parse_date("#{year}-#{month}")
    end

    it "should handle dates with impossible day" do
      year = 2017
      month = 11
      day = 32
      assert_equal Date.new(year, month, 1),
                   Capapi::DataHelpers.parse_date("#{year}-#{month}-#{day}")
    end

    it "should handle dates with impossible month and day" do
      year = 2017
      month = 13
      day = 32
      assert_equal Date.new(year, month, 1),
                   Capapi::DataHelpers.parse_date("#{year}-#{month}-#{day}")
    end

    it "should raise an exeception when passing a non-date string" do
      assert_raises ArgumentError do
        Capapi::DataHelpers.parse_date("not a date")
      end
    end
  end
end
