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

    fill_in 'Title', with: 'New Title'    
    click_button 'Save'
    assert_content 'Casebook successfully updated'
    assert_content 'New Title'
  end

  scenario 'deleting a case', js: true do
  kase = cases(:public_case_1)
    visit(rails_admin.edit_path(model_name: 'case', id: kase.id))

    click_link 'Delete'
    click_button 'Yes, I\'m sure'
    assert_content 'Case successfully deleted'
  end

  scenario 'deleting a text block', js: true do
    text_block = text_blocks(:public_text_1)
    visit(rails_admin.edit_path(model_name: 'text_block', id: text_block.id))

    click_link 'Delete'
    click_button 'Yes, I\'m sure'
    assert_content 'Text successfully deleted'
  end

  scenario 'deleting a link (default)', js: true do
    link = defaults(:link_one)
    visit(rails_admin.edit_path(model_name: 'default', id: link.id))

    click_link 'Delete'
    click_button 'Yes, I\'m sure'
    assert_content 'Link successfully deleted'
  end
end
