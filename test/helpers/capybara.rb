
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
  def go_back
    visit page.driver.request.env['HTTP_REFERER']
  end
end

class Capybara::Session
  def submit(element)
    Capybara::RackTest::Form.new(driver, element.native).submit({})
  end
end
