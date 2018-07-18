# frozen_string_literal: true

module Capapi
  class Jurisdiction < APIResource
    extend Capapi::APIOperations::List
    OBJECT_NAME = "jurisdiction".freeze
  end
end
