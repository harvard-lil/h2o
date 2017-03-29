if ENV['COVERAGE']
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.start do
    add_filter 'app/secrets'
  end
end

# Removed for rails 5
# require 'minitest/rails/capybara'
# require 'capybara/poltergeist'


ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require 'rails/test_help'
require 'wrong/adapters/minitest'
require 'minitest/reporters'
Minitest::Reporters.use!


class ActiveSupport::TestCase
  self.use_transactional_tests = true
  fixtures :all
end

module H2o
  module Test
    module Helpers
    end
  end
end
