require "test_helper"

feature 'landing page' do
  describe 'content' do
    before :all do
      visit root_path
    end
    test('welcome message') { assert_content /welcome to h2o/i }
    test('call to action') { assert_link 'Get Started' }
    test('login link') { assert_link 'sign in' }
  end
end
