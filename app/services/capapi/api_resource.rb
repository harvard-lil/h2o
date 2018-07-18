# frozen_string_literal: true

module Capapi
  class APIResource < CapapiObject
    include Capapi::APIOperations::Request

    def self.class_name
      name.split("::")[-1]
    end

    def self.resource_url
      if self == APIResource
        raise NotImplementedError, "APIResource is an abstract class.  You should perform actions on its subclasses (Charge, Customer, etc.)"
      end
      "/v#{Capapi.api_version}/#{CGI.escape(class_name.downcase)}s/"
    end

    def resource_url
      unless (id = self["id"])
        raise InvalidRequestError.new("Could not determine which URL to request: #{self.class} instance has invalid ID: #{id.inspect}", "id")
      end
      "#{self.class.resource_url}#{CGI.escape(id)}"
    end

    def refresh
      resp, opts = request(:get, resource_url, @retrieve_params)
      initialize_from(resp.data, opts)
    end

    def self.retrieve(id, opts = {})
      opts = Util.normalize_opts(opts)
      instance = new(id, opts)
      instance.refresh
      instance
    end
  end
end
