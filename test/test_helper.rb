if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails'
end

require 'securerandom'

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

class Capybara::Rails::TestCase
  def random_token
    # convenience method to generate a short random string
    SecureRandom.base64 8
  end
  def sign_in user
    # This directly logs in the user.
    # Don't use this when testing login itself!
    user.set_password = password = random_token
    user.save!
    page.driver.post user_sessions_path, :user_session => {:login => user.login, :password => password}
  end
  def sign_out
    page.driver.get log_out_path
  end
end
