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

    def self.to_attributes capapi_obj
      case capapi_obj
      when Capapi::Case
        attributes = { capapi: capapi_obj,
                       case_court_attributes: to_attributes(capapi_obj.court),
                       name_abbreviation: capapi_obj.name_abbreviation,
                       name: capapi_obj.name,
                       decision_date: DataHelpers.parse_date(capapi_obj.decision_date),
                       docket_number: capapi_obj.docket_number,
                       citations: capapi_obj.citations.map(&method(:to_attributes)) }
        if capapi_obj.casebody_loaded?
          html = HTMLUtils.parse(capapi_obj.casebody["data"])
          attributes = attributes.merge({ content: capapi_obj.casebody["data"],
                                          attorneys: html.css('.attorneys').collect(&:text),
                                          parties: html.css('.parties').collect(&:text),
                                          opinions: html.css('.opinion').collect { |el| {el['data-type'] => el.css('.author').text} }})
        end
        attributes
      when Capapi::Court
        { capapi: capapi_obj,
          name: capapi_obj.name,
          name_abbreviation: capapi_obj.name_abbreviation }
      when Capapi::Citation
        { type: capapi_obj.type,
          cite: capapi_obj.cite }
      end
    end
  end
end
