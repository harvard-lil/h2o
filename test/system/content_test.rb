require 'application_system_test_case'

class ContentSystemTest < ApplicationSystemTestCase
  scenario 'landing page' do
    visit root_path

    assert_content /Build a better casebook/i
    assert_link 'Sign up for free'
    assert_link 'View a book'
    assert_link 'Sign in'
  end
  scenario 'footer links' do
    visit root_path
    assert_link 'Terms of Service'
    assert_link 'Privacy Policy'
    assert_link 'About'
    assert_link 'User Guide'
    assert_link 'FAQ'
  end
end
