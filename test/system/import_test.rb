require 'application_system_test_case'

class CaseImportSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  scenario 'importing from dropbox', js: true do
    SimpleCov.add_filter %w{lib/dropbox app/controllers/dropbox_sessions_controller.rb app/controllers/bulk_uploads_controller.rb app/jobs/bulk_upload_job.rb}
    skip 'Dropbox import is disabled.'

    # TODO: stub dropbox api?
    page.driver.browser.url_whitelist = %w(://127.0.0.1:* https://www.dropbox.com https://cfl.dropboxstatic.com)

    sign_in users(:case_admin)

    visit new_bulk_upload_path
    assert_current_path %r{/1/oauth/authorize}

    # Test token has been oauthed manually in advance; this is its serialized session with valid access_token
    serialized_dropbox_session = "---\n- payc98h8onevsk7\n- 3bctjz2m2r1ywvx6\n- uSYtG8hGX0EfmkSD\n- MYib6yCIRp7tEYmc\n- wilyn7564dnz81a\n- ce21mrph0i7vg92\n"

    visit dropbox_sessions_path(oauth_token: "TEST_TOKEN", serialized_dropbox_session: serialized_dropbox_session)
    assert_current_path new_bulk_upload_path

    assert_content '731se2d550.xml'
    perform_enqueued_jobs do
      click_button 'UPLOAD!'
    end

    assert_content 'Download started.'


    # TODO: Implement and test proper job queue
    # TODO: Test the notification email

    assert_content 'Successful Imports 731se2d550.xml'

    # TODO: Give case_admin fixture privs to do this:

    # click_link 'Edit Couple v. Baby Girl'
    # check 'Public'
    # click_button 'Save'
  end
end
