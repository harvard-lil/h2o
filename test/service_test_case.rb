require 'test_helper'

require 'minitest/metadata'

require 'helpers/email'
require 'helpers/cap_api_import'

class ServiceTestCase < ActionDispatch::TestCase 
	include MiniTest::Metadata
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  include H2o::Test::Helpers::Email
  include H2o::Test::Helpers::CapApiImport
end