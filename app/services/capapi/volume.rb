# frozen_string_literal: true

module Capapi
  class Volume < APIResource
    extend Capapi::APIOperations::List
    OBJECT_NAME = "volume".freeze
  end
end
