require 'application_system_test_case'

class IFrameSystemTest < ApplicationSystemTestCase
  {case: :public_case_1}.each do |key, fixture|
    scenario "iframe for a #{key}" do
      fixture = send(:"#{key}s", fixture)
      visit iframe_load_path type: "#{key}s", id: fixture.id
      assert_content fixture.name

      click_link 'Open page in'
      assert_current_path send(:"#{key}_path", fixture)

      visit iframe_show_path type: "#{key}s", id: fixture.id
      assert_content fixture.name
    end
  end
end
