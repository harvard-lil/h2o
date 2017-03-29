require 'securerandom'
module H2o::Test::Helpers::Capybara
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
  def simulate_mouse_event(selector, event_name, xy={})
    # Trigger an event with options
    page.execute_script <<-JS
    var event = document.createEvent('MouseEvent');
    event.initMouseEvent('#{event_name}', true, true, window,
                     {}, 0, 0, #{xy['x']}, #{xy['y']},
                     false, false,false,false,
                     0, null);
      $('#{selector}')[0].dispatchEvent(event);
    JS
  end
  def simulate_drag src, targ
    drag_xy = page.find(src).click
    drop_xy = page.find(targ).click

    simulate_mouse_event src, :mousedown, drag_xy['position']
    simulate_mouse_event src, :mousemove, drop_xy['position']
    simulate_mouse_event src, :mousemove, drop_xy['position']
    simulate_mouse_event src, :mouseup, drop_xy['position']
  end
end

class Capybara::Session
  def submit(element)
    Capybara::RackTest::Form.new(driver, element.native).submit({})
  end
end
