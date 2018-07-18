# frozen_string_literal: true

module Capapi
  class Case < APIResource
    extend Capapi::APIOperations::List
    OBJECT_NAME = "case".freeze
  end
end
