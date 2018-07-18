# frozen_string_literal: true

module Capapi
  class Reporter < APIResource
    extend Capapi::APIOperations::List
    OBJECT_NAME = "reporter".freeze
  end
end
