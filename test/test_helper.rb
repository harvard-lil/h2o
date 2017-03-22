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
    url_blacklist: %w(use.typekit.net),
    extensions: %w(rangy-1.3.0/rangy-core.js rangy-1.3.0/rangy-textrange.js).map {|p| File.expand_path("../helpers/phantomjs/#{p}", __FILE__)}
end
Capybara.javascript_driver = :poltergeist
Capybara.default_max_wait_time = 2.seconds

require "transactional_capybara"
TransactionalCapybara.share_connection

require 'minitest/reporters'
Minitest::Reporters.use!

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all
  # Add more helper methods to be used by all tests here...
  after :each do
    TransactionalCapybara::AjaxHelpers.wait_for_ajax(page)
  end
  before :each do
    if ENV['CAPYBARA_SKIP_JS'] && metadata[:js] && !metadata[:focus]
      skip 'Automatic tests skip JavaScript. Run `bin/rake test:all`, or add `focus: true` to enable for this test.'
    end
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
