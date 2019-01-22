require 'securerandom'
module H2o::Test::Helpers::Capybara
  include ActionView::Helpers::JavaScriptHelper

  def assert_path_changes
    # assert a redirect has occurred during block
    path = current_path
    yield
    assert_no_current_path path
  end

  def assert_links_to test_url
    begin
      yield
    rescue ActionController::RoutingError => e
      # Swallow routing errors, allowing offsite url asserts in Rack::Test
      logger.warn "A RoutingError was suppressed by `assert_links_to`: #{e.inspect}"
    end
    assert { current_url == test_url }
  end

  def random_token
    # generate a short random string
    SecureRandom.base64 8
  end

  def download_file url, to:
    downloads_dir = Rails.root.join("tmp/downloads")
    out_path = downloads_dir.join(to)
    Dir.mkdir downloads_dir unless File.exists?(downloads_dir)
    IO.copy_stream(open(url), out_path)
    out_path
  end

  def select_text text
    page.execute_script <<-JS
        let text = '#{escape_javascript text}';
        let nodeIterator = document.createNodeIterator(
            document.body,
            NodeFilter.SHOW_TEXT,
            {acceptNode(node) {
              if(node.textContent.includes(text)){
                return NodeFilter.FILTER_ACCEPT;
              }
            }});
        let node = nodeIterator.nextNode();
        let range = document.createRange();
        range.setStart(node, node.textContent.indexOf(text));
        range.setEnd(node, node.textContent.indexOf(text) + text.length);
        let sel = window.getSelection();
        sel.addRange(range);
    JS
  end

  def sign_in user
    # This directly logs in the user.
    # Don't use this when testing login itself!
    user.set_password = password = random_token
    # puts "******"
    # puts user.email_address
    # puts password
    # puts "******"
    user.save!
    if page.driver.is_a? Capybara::RackTest::Driver
      page.driver.post user_sessions_path, user_session: {email_address: user.email_address, password: password}
    else # e.g. Capybara::Selenium::Driver
      visit new_user_session_path
      fill_in 'Email address', with: user.email_address
      fill_in 'Password', with: password
      click_button 'Sign in'
      assert_content user.display_name
    end
    password
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
                     {}, 0, 0, #{xy[:x]}, #{xy[:y]},
                     false, false,false,false,
                     0, null);
      $('#{selector}')[0].dispatchEvent(event);
    JS
  end

  def simulate_drag_drop source, target, position: :top
    execute_script <<-JS
      var source = document.querySelector('#{source}');
      var target = document.querySelector('#{target}');
      window.ACTIVE_DRAGMOCK = dragMock
      .dragStart(source)
      .dragEnter(target)
    JS

    drop_rect = evaluate_script "document.querySelector('#{target}').getBoundingClientRect()"
    drop_position = {
      clientX: drop_rect['left'] + drop_rect['width'] / 2,
      clientY: drop_rect['top'] + drop_rect['height'] / 2
    }
    if position == :top
      drop_position[:clientY] -= 50
    elsif position == :bottom
      drop_position[:clientY] += 5
    end

    execute_script <<-JS
      var target = document.querySelector('#{target}');
      ACTIVE_DRAGMOCK.dragOver(target, #{drop_position.to_json})
      .drop(target, #{drop_position.to_json});
    JS
  end
  def reload_page
    page.evaluate_script("window.location.reload()")
  end
end

class Capybara::Session
  def submit(element)
    case Capybara.current_driver
        when :rack_test
          Capybara::RackTest::Form.new(driver, element.native).submit({})
        when :selenium
          element.find('input').native.send_keys(:enter)
    end
  end
end
