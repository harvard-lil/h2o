if !ENV['CAPYBARA_SKIP_JS']
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [SimpleCov::Formatter::HTMLFormatter, Coveralls::SimpleCov::Formatter]
  SimpleCov.start 'rails' do
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
  def logger; Rails.logger; end
  self.use_transactional_tests = true
  fixtures :all
  before :each do
    Rails.cache.clear
    ActionMailer::Base.deliveries.clear
  end
end

module H2o
  module Test
    module Helpers
    end
  end
end
