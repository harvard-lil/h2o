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
  Capybara::Poltergeist::Driver.new app,
    js_errors: true,
    url_whitelist: %w(://127.0.0.1:*),
    extensions: %w(rangy-1.3.0/rangy-core.js rangy-1.3.0/rangy-textrange.js).map {|p| File.expand_path("../helpers/phantomjs/#{p}", __FILE__)}
end
Capybara.javascript_driver = :poltergeist
Capybara.default_max_wait_time = 10.seconds

require 'helpers/capybara'

require 'database_cleaner'

require 'minitest/reporters'
Minitest::Reporters.use!


class ActiveSupport::TestCase
  self.use_transactional_fixtures = false
  fixtures :all

  # Disable sunspot for most tests
  sunspot_test_session = Sunspot.session
  sunspot_stub_session = Sunspot::Rails::StubSessionProxy.new(sunspot_test_session)
  Sunspot.session = sunspot_stub_session

  before :each do
    if ENV['CAPYBARA_SKIP_JS'] && metadata[:js] && !metadata[:focus]
      # TODO:
      skip 'Automatic tests skip JavaScript. Run `bin/rake test:all`, or add `focus: true` to enable for this test.'
      return
    end

    if metadata[:js] || metadata[:solr]
      DatabaseCleaner.strategy = :truncation, {pre_count: true}
    else
      DatabaseCleaner.strategy = :transaction
    end
    DatabaseCleaner.start

    if metadata[:solr]
      Sunspot.session = sunspot_test_session
      metadata[:solr].each &:index
    end
  end
  after :each do
    DatabaseCleaner.clean
    if metadata[:solr]
      metadata[:solr].each &:remove_all_from_index!
      Sunspot.session = sunspot_stub_session
    end
  end
end
