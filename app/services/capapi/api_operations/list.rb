# frozen_string_literal: true

module Capapi
  module APIOperations
    module List
      def list(filters = {}, opts = {}, path = resource_url, object_name = const_get(:OBJECT_NAME))
        opts = Util.normalize_opts(opts)

        resp, opts = request(:get, path, filters, opts)
        ListObject.construct_from(resp.data, opts, object_name)
      end
    end
  end
end
