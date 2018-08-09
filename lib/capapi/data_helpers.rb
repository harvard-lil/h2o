module Capapi
  module DataHelpers
    def self.parse_date date_str
      fmt = "%Y"
      fmt += "-%m" if date_str === /\d{4}-\d{2}/
      fmt += "-%d" if date_str === /\d{4}-\d{2}-\d{2}/
      Date.strptime(date_str, fmt)
    end
  end
end
