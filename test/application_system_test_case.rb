require 'test_helper'

require 'capybara/poltergeist'
require 'minitest/metadata'

require 'helpers/capybara'
require 'helpers/drivers'
require 'helpers/dsl'
require 'helpers/sunspot'
require 'helpers/email'
require 'helpers/files'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include MiniTest::Metadata
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  include H2o::Test::Helpers::Capybara
  include H2o::Test::Helpers::Drivers
  include H2o::Test::Helpers::DSL
  include H2o::Test::Helpers::Sunspot
  include H2o::Test::Helpers::Email
  include H2o::Test::Helpers::Files

  def before_all
    # Include forgery protection for system tests
    @forgery_default = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  def after_all
    ActionController::Base.allow_forgery_protection = @forgery_default
  end

  def assert_api(action, db_type)
    count = action == :creates ? 1 : -1
    assert_difference "#{db_type}.count", count  do
      yield
      sleep 1
    end
  end
end
