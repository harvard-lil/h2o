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
Capybara.default_max_wait_time = 3.seconds

require 'database_cleaner'

require 'minitest/reporters'
Minitest::Reporters.use!

class ActiveSupport::TestCase
  self.use_transactional_fixtures = false
  fixtures :all
  before :each do
    if ENV['CAPYBARA_SKIP_JS'] && metadata[:js] && !metadata[:focus]
      skip 'Automatic tests skip JavaScript. Run `bin/rake test:all`, or add `focus: true` to enable for this test.'
    else
      if metadata[:js]
        DatabaseCleaner.strategy = :truncation, {pre_count: true}
      else
        DatabaseCleaner.strategy = :transaction
      end
      DatabaseCleaner.start
    end
  end
  after :each do
    DatabaseCleaner.clean
  end
end

class Capybara::Rails::TestCase
  include ActionView::Helpers::JavaScriptHelper
  def assert_path_changes
    # assert a redirect has occurred during block
    path = current_path
    yield
    assert_no_current_path path
  end
  def random_token
    # generate a short random string
    SecureRandom.base64 8
  end
  def select_text text
    node = page.execute_script <<-JS
        var range = rangy.createRange();
        range.findText('#{escape_javascript text}');
        rangy.getSelection().addRange(range);
        range.startContainer.parentElement.className += ' selected-container';
    JS
    find('.selected-container').trigger :mouseup
  end
  def sign_in user
    # This directly logs in the user.
    # Don't use this when testing login itself!
    user.set_password = password = random_token
    user.save!
    case page.driver
    when Capybara::RackTest::Driver
      page.driver.post user_sessions_path, user_session: {login: user.login, password: password}
    else # e.g. Capybara::Selenium::Driver
      visit new_user_session_path
      fill_in 'Login', with: user.login
      fill_in 'Password', with: password
      click_button 'Login'
    end
  end
  def sign_out
      visit log_out_path
  end
end
