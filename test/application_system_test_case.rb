require 'test_helper'

require 'capybara/poltergeist'
require 'minitest/metadata'

require 'helpers/capybara'
require 'helpers/drivers'
require 'helpers/dsl'
require 'helpers/sunspot'
require 'helpers/email'
require 'helpers/files'
require 'helpers/case_finder_data'

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
  include H2o::Test::Helpers::CaseFinderData
end
