require 'application_system_test_case'

feature 'redirects' do
  scenario 'bad formats' do
    visit '/anything.php'
    assert_current_path '/'

    assert_raises ActionController::RoutingError do
      visit '/anything.zip'
    end
  end

  scenario 'auth error' do
    visit case_path cases(:private_case_1)
    assert_content "You are not authorized to access this page."
  end

  scenario 'user edit' do
    sign_in user = users(:student_user)
    visit edit_user_path user
    assert_current_path user_path user
  end
end
