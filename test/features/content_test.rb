require 'application_system_test_case'

class ContentSystemTest < ApplicationSystemTestCase
  scenario 'landing page' do
    visit root_path

    assert_content /welcome to h2o/i
    assert_link 'Get Started'
    assert_link 'sign in'
  end
  scenario 'footer links' do
    visit root_path
    footer_page =  pages(:footer_page_1)
    click_link footer_page.footer_link_text

    assert_content footer_page.content
    assert_content footer_page.page_title
  end
end
