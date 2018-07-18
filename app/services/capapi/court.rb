# frozen_string_literal: true

module Capapi
  class Court < APIResource
    extend Capapi::APIOperations::List
    OBJECT_NAME = "court".freeze
  end
end
