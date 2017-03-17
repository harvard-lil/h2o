if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails'
end

ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require 'rails/test_help'
require 'minitest/rails'
require 'wrong/adapters/minitest'

require 'minitest/rails/capybara'
require 'capybara/poltergeist'
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new app, js_errors: true, url_blacklist: %w(use.typekit.net)
end
Capybara.javascript_driver = :poltergeist
Capybara.default_max_wait_time = 2.seconds

require 'minitest/reporters'
Minitest::Reporters.use!

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all
  # Add more helper methods to be used by all tests here...
end
