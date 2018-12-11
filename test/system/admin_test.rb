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

  describe 'deleting a resource' do 
    scenario 'deleting a case', js: true do
      kase = cases(:unused_case)
      visit(rails_admin.edit_path(model_name: 'case', id: kase.id))

      click_link 'Delete'

      click_button 'Yes, I\'m sure'
      assert_content 'Case successfully deleted'
    end

    scenario 'can\'t delete a case that is used in a casebook', js: true do
      kase = cases(:public_case_1)
      visit(rails_admin.edit_path(model_name: 'case', id: kase.id))

      click_link 'Delete'

      assert_content "Can't delete Case because it's used in casebooks:"
      refute_button 'Yes, I\'m sure'
    end

    scenario 'deleting a text block', js: true do
      text_block = text_blocks(:unused_text)
      visit(rails_admin.edit_path(model_name: 'text_block', id: text_block.id))

      click_link 'Delete'

      click_button 'Yes, I\'m sure'
      assert_content 'Text successfully deleted'
    end

    scenario 'can\'t delete a text block that is used in a casebook', js: true do
      text_block = text_blocks(:public_text_1)
      visit(rails_admin.edit_path(model_name: 'text_block', id: text_block.id))

      click_link 'Delete'

      assert_content "Can't delete TextBlock because it's used in casebooks:"
      refute_button 'Yes, I\'m sure'
    end

    scenario 'deleting a link (default)', js: true do
      link = defaults(:unused_link)
      visit(rails_admin.edit_path(model_name: 'default', id: link.id))

      click_link 'Delete'
      click_button 'Yes, I\'m sure'
      assert_content 'Link successfully deleted'
    end

    scenario 'can\'t delete a link(default) that is used in a casebook', js: true do
      link = defaults(:link_one)
      visit(rails_admin.edit_path(model_name: 'default', id: link.id))

      click_link 'Delete'
      assert_content "Can't delete Default because it's used in casebooks:"
      refute_button 'Yes, I\'m sure'
    end
  end

  describe 'casebook collaborators' do
    describe 'adding a collaborator' do
      let (:casebook) { content_nodes(:public_casebook) }
      let (:original_collaborator_attribution) { users(:verified_professor).attribution }
      let (:verified_student) { users(:verified_student) }
      
      before do 
        visit(rails_admin.edit_path(model_name: 'content~casebook', id: casebook.id))
        click_link 'Manage Collaborators'
        fill_in 'search', with: 'verified_student'
        find('.search-field').send_keys :enter
        sleep 0.3
      end

      scenario 'add collaborator to a casebook', js: true do
        click_button 'Add Collaborator'
        sleep 0.3

        refute_button 'Add Collaborator' # no search results present
        assert_content 'verified_student'
        assert_content original_collaborator_attribution
      end

      scenario 'add collaborator with attribution and see that on the user view', js: true do
        within "#has-attribution-#{verified_student.id}" do
          find("#has_attribution").click
        end
        click_button 'Add Collaborator'

        sleep 0.3

        refute_button 'Add Collaborator' # no search results present
        assert_content 'verified_student'
        has_checked_field?("#has_attribution_#{verified_student.id}")
        assert_content original_collaborator_attribution

        visit casebook_path casebook

        assert_content 'verified_student'
        refute_content original_collaborator_attribution
      end
    end

    scenario 'removing attribution from a collaborator hides them from user view', js: true do
      casebook = content_nodes(:draft_casebook)
      original_collaborator = users(:verified_professor)

      visit(rails_admin.edit_path(model_name: 'content~casebook', id: casebook.id))
      click_link 'Manage Collaborators'

      assert_content original_collaborator.attribution

      within "#has-attribution-#{original_collaborator.id}" do
        find("#has_attribution").click
      end

      click_button 'Update'

      sleep 0.3

      has_unchecked_field?("#has_attribution_#{original_collaborator.id}")

      visit casebook_path casebook

      refute_content original_collaborator
    end
  end
end
