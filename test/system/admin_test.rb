require 'application_system_test_case'

class AdminSystemTest < ApplicationSystemTestCase
  before do
    sign_in @user = users(:site_admin)
  end

  scenario 'creating a new page', js: true do
    visit rails_admin_path

    within '.sidebar-nav' do
      click_link 'Pages'
    end
    assert_content 'List of Pages'
    click_link 'Add new'
    assert_content 'New Page'

    fill_in 'Slug', with: 'test-page'
    wait_until(wait: 10.seconds) {evaluate_script "CKEDITOR.instances['page_content'].loaded"}
    sleep 3 # trying to make this a bit more reliable
    evaluate_script "CKEDITOR.instances['page_content'].insertHtml('This is some page content.')"
    assert { evaluate_script("CKEDITOR.instances['page_content'].execCommand('image')") }
    assert_content 'Image Properties'
    click_link 'Upload'
    click_link 'Upload' # ?
    within_frame find('iframe.cke_dialog_ui_input_file') do
      attach_file 'upload', upload_file_path('page-image.png')
    end
    click_link 'Send it to the Server'
    click_link 'OK'

    assert_equal true, evaluate_script("CKEDITOR.instances['page_content'].execCommand('link')")
    assert_content 'Link'
    click_link 'Upload'
    within_frame find('iframe.cke_dialog_ui_input_file') do
      attach_file 'upload', upload_file_path('page-image.png')
    end
    click_link 'Send it to the Server'
    click_link 'OK'

    click_button 'Save'
  end

  scenario 'editing a casebook', js: true do
    casebook = content_nodes(:public_casebook)

    visit(rails_admin.edit_path(model_name: 'content~casebook', id: casebook.id))

    click_button 'Save'

    assert_content 'Casebook sucessfully updated'
  end
end
