module Capapi
  module ModelHelpers
    def capapi_id=(new_id)
      if new_id != capapi_id
        @capapi = nil
        super new_id
      end
    end

    def capapi
      @capapi ||= self.class.const_get("CAPAPI_CLASS").new(capapi_id) if capapi_id
    end

    def capapi= capapi_case
      if capapi_case
        self.capapi_id = capapi_case.id
        @capapi = capapi_case
      else
        capapi_id = nil
      end
    end
  end
end
