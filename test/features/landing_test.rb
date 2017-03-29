require 'application_system_test_case'

feature 'landing page' do
  scenario 'anonymous user' do
    visit root_path

    assert_content /welcome to h2o/i
    assert_link 'Get Started'
    assert_link 'sign in'
  end
end
