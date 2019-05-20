if !ENV['CAPYBARA_SKIP_JS']
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [SimpleCov::Formatter::HTMLFormatter, Coveralls::SimpleCov::Formatter]
  SimpleCov.start 'rails' do
    add_filter 'app/secrets'
    add_filter %w{app/models/migrate lib/migrate}
  end
end

# Removed for rails 5
# require 'minitest/rails/capybara'
# require 'capybara/poltergeist'

ENV["RAILS_ENV"] = "test"

require File.expand_path("../../config/environment", __FILE__)
require 'rails/test_help'
require 'minitest/reporters'
require 'webmock/minitest'

WebMock.disable_net_connect!(allow_localhost: true)
Minitest::Reporters.use!
Rails.backtrace_cleaner.remove_silencers! if ENV['DEBUG']

# load "#{Rails.root}/db/seeds.rb"

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
