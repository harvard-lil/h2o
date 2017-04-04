require 'application_system_test_case'

feature 'exporting' do
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  scenario 'exporting a case to .docx', js:true do
    sign_in user = users(:verified_student)
    visit case_path public_case = cases(:public_case_1)

    click_link 'Print'

    assert_content public_case.short_name
    assert_content public_case.content

    select 'DOCX', from: 'export_format'

    perform_enqueued_jobs do
      click_link 'export-form-submit'
      assert_content 'H2O is exporting your content to DOCX format.'
      assert_sends_emails 1, wait: 10.seconds # This needs to be in the block for some reason
    end

    email = ActionMailer::Base.deliveries.first
    assert { email.to.include? user.email_address }
    assert { email.body.match(/(http.+?\.docx)/) }
    exported_file_url = email.body.match(/(http.+?\.docx)/)[1]

    downloaded_path = download_file exported_file_url, to: 'test_export_case.docx'
    assert  { %x{shasum #{downloaded_path}}.split().first == %x{shasum #{Rails.root.join('test/files/test_export_case.docx')}}.split().first }
  end

  scenario 'exporting a playlist to .docx', js:true do
    sign_in user = users(:verified_student)
    visit playlist_path public_playlist = playlists(:public_playlist_1)

    click_link 'Print'

    assert_content public_playlist.name

    select 'DOCX', from: 'export_format'

    perform_enqueued_jobs do
      click_link 'export-form-submit'
      assert_content 'H2O is exporting your content to DOCX format.'
      assert_sends_emails 1, wait: 10.seconds # This needs to be in the block for some reason
    end

    email = ActionMailer::Base.deliveries.first
    assert { email.to.include? user.email_address }
    assert { email.body.match(/(http.+?\.docx)/) }
    exported_file_url = email.body.match(/(http.+?\.docx)/)[1]

    downloaded_path = download_file exported_file_url, to: 'test_export_playlist.docx'
    assert  { %x{shasum #{downloaded_path}}.split().first == %x{shasum #{Rails.root.join('test/files/test_export_playlist.docx')}}.split().first }
  end

  scenario 'exporting a case to .pdf', js:true do
    sign_in user = users(:verified_student)
    visit case_path public_case = cases(:public_case_1)

    click_link 'Print'

    assert_content public_case.short_name
    assert_content public_case.content

    select 'PDF', from: 'export_format'

    perform_enqueued_jobs do
      click_link 'export-form-submit'
      assert_content 'H2O is exporting your content to PDF format.'
      assert_sends_emails 1, wait: 10.seconds # This needs to be in the block for some reason
    end

    email = ActionMailer::Base.deliveries.first
    assert { email.to.include? user.email_address }
    assert { email.body.match(/(http.+?\.pdf)/) }
    exported_file_url = email.body.match(/(http.+?\.pdf)/)[1]

    downloaded_path = download_file exported_file_url, to: 'test_export_case.pdf'
    assert  { %x{shasum #{downloaded_path}}.split().first == %x{shasum #{Rails.root.join('test/files/test_export_case.pdf')}}.split().first }
  end

  scenario 'exporting a playlist to .pdf', js:true do
    sign_in user = users(:verified_student)
    visit playlist_path public_playlist = playlists(:public_playlist_1)

    click_link 'Print'

    assert_content public_playlist.name

    select 'PDF', from: 'export_format'

    perform_enqueued_jobs do
      click_link 'export-form-submit'
      assert_content 'H2O is exporting your content to PDF format.'
      assert_sends_emails 1, wait: 10.seconds # This needs to be in the block for some reason
    end

    email = ActionMailer::Base.deliveries.first
    assert { email.to.include? user.email_address }
    assert { email.body.match(/(http.+?\.pdf)/) }
    exported_file_url = email.body.match(/(http.+?\.pdf)/)[1]

    downloaded_path = download_file exported_file_url, to: 'test_export_playlist.pdf'
    assert  { %x{shasum #{downloaded_path}}.split().first == %x{shasum #{Rails.root.join('test/files/test_export_playlist.pdf')}}.split().first }
  end

  scenario 'exporting a text to .docx', js:true do
    sign_in user = users(:verified_student)
    visit text_block_path public_text = text_blocks(:public_text_1)

    click_link 'Print'

    assert_content public_text.name
    assert_content public_text.content

    select 'DOCX', from: 'export_format'

    perform_enqueued_jobs do
      click_link 'export-form-submit'
      assert_content 'H2O is exporting your content to DOCX format.'
      assert_sends_emails 1, wait: 10.seconds # This needs to be in the block for some reason
    end

    email = ActionMailer::Base.deliveries.first
    assert { email.to.include? user.email_address }
    assert { email.body.match(/(http.+?\.docx)/) }
    exported_file_url = email.body.match(/(http.+?\.docx)/)[1]

    downloaded_path = download_file exported_file_url, to: 'test_export_text.docx'
    assert  { %x{shasum #{downloaded_path}}.split().first == %x{shasum #{Rails.root.join('test/files/test_export_text.docx')}}.split().first }
  end

  scenario 'exporting a text to .pdf', js:true do
    sign_in user = users(:verified_student)
    visit text_block_path public_text = text_blocks(:public_text_1)

    click_link 'Print'

    assert_content public_text.name
    assert_content public_text.content

    select 'PDF', from: 'export_format'

    perform_enqueued_jobs do
      click_link 'export-form-submit'
      assert_content 'H2O is exporting your content to PDF format.'
      assert_sends_emails 1, wait: 10.seconds # This needs to be in the block for some reason
    end

    email = ActionMailer::Base.deliveries.first
    assert { email.to.include? user.email_address }
    assert { email.body.match(/(http.+?\.pdf)/) }
    exported_file_url = email.body.match(/(http.+?\.pdf)/)[1]

    downloaded_path = download_file exported_file_url, to: 'test_export_text.pdf'
    assert  { %x{shasum #{downloaded_path}}.split().first == %x{shasum #{Rails.root.join('test/files/test_export_text.pdf')}}.split().first }
  end
end
