module Capapi
  module DataHelpers
    def self.parse_date date_str
      fmt = default = "%Y"
      fmt += "-%m" if /^\d{4}-\d{2}/ === date_str
      fmt += "-%d" if /^\d{4}-\d{2}-\d{2}$/ === date_str

      begin
        Date.strptime(date_str, fmt)
      rescue ArgumentError => e
        if fmt == default
          raise e
        else
          parse_date(date_str[0..-4])
        end
      end
    end
  end
end
