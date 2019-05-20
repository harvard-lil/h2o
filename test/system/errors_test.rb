require 'application_system_test_case'

class ErrorsSystemTest < ApplicationSystemTestCase
  scenario 'bad formats' do
      visit '/anything.php'
      assert_equal page.status_code, 404
      assert_content "We can't seem to find the page you are looking for."

      visit '/anything.zip'
      assert_equal page.status_code, 404
      assert_content "We can't seem to find the page you are looking for."
  end

  scenario 'not found' do
    visit '/foo'
    assert_equal page.status_code, 404
    assert_content "We can't seem to find the page you are looking for."

    visit '/foo/bar'
    assert_equal page.status_code, 404
    assert_content "We can't seem to find the page you are looking for."

    visit casebook_path 'foo'
    assert_equal page.status_code, 404
    assert_content "We can't seem to find the page you are looking for."
  end

  scenario 'auth error' do
    visit case_path cases(:private_case_1)
    assert_content "You are not authorized to access this page."
  end
end
