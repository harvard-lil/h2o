# frozen_string_literal: true

module Capapi
  class Citation < APIResource
    extend Capapi::APIOperations::List
    OBJECT_NAME = "citation".freeze
  end
end
