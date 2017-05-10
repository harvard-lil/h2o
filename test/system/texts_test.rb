require 'application_system_test_case'

class TextsSystemTest < ApplicationSystemTestCase
  # FYI texts are called TextBlocks
  describe 'as an anonymous user' do
    scenario 'browsing texts', solr: true do
      visit text_blocks_path
      assert_content 'Public Text 1'
      assert_no_content 'Private Text 1'
    end

    scenario 'searching for a text', solr: true do
      visit search_all_path
      search_label = [*'XA'..'XZ'].sample
      fill_in 'Keywords', with: "Text #{search_label}"
      # click_link 'SEARCH' # TODO: This should not require JavaScript!
      page.submit find('form.search')

      assert_content "Search Results: Text #{search_label}"
      assert_content "1 Text Total"

      click_link "Haystack Text (#{search_label})"
      assert_content "This is haystack text labeled #{search_label}"

      # Can't find a private text!
      # TODO: You really should be able to find a private text that belongs to you.
      search_label = [*'YA'..'YZ'].sample
      fill_in 'Keywords', with: "Text #{search_label}"
      page.submit find('form.search')

      assert_content "Search Results: Text #{search_label}"
      assert_content "0 Results Total"

      # Simulate a text edit
      search_label = [*'XA'..'XZ'].sample
      text_blocks(:"haystack_text_#{search_label}").update! name: "Updated Haystack Text (#{search_label})"
      Sunspot.commit # TODO: Test this properly

      fill_in 'Keywords', with: "Updated Haystack Text"
      page.submit find('form.search')

      assert_content "Search Results: Updated Haystack Text"
      assert_content "1 Text Total"
      assert_content "Updated Haystack Text (#{search_label})"
    end

    scenario 'reading a text' do
      text = text_blocks(:public_text_1)

      visit text_block_path text
      assert_content text.name
      assert_content text.content
      assert_content text.user.display_name
    end
  end
  describe 'as a registered user' do
    scenario 'browsing, searching, and reading texts' do
      text = text_blocks(:private_text_1)
      visit text_block_path text_blocks(:private_text_1)

      assert_content 'You are not authorized to access this page.'
      refute_content text.content

      sign_in users(:verified_professor)

      visit text_block_path text_blocks(:private_text_1)

      assert_content text.content
    end

    scenario 'annotating a text', js: true do
      skip 'replacing annotating with casebook code'
      sign_in user = users(:verified_student)
      visit text_block_path public_text = text_blocks(:public_text_to_annotate)

      click_link 'Clone and Annotate'
      assert_xpath "//input[@value='#{public_text.name}']"

      # TODO: make mce tests more intuitive than this
      annotated_desc = "Test annotated text desc: #{random_token}"
      within_frame find('#collage_description_input .mce-tinymce iframe', visible: false) do
        find('body').set annotated_desc
      end

      click_button 'Submit'

      assert_link 'ANNOTATION DISPLAY'
      assert_content annotated_desc
      # TODO: make these buttons more accessible

      # Highlighting
      select_text 'content to highlight'
      find('[title=highlight]').trigger 'click'
      click_link 'ffee00'
      click_link 'Save'
      find('.highlight-hex-ffee00').assert_text 'content to highlight'

      # Elision
      select_text 'content to elide'
      find('[title=hide]').trigger 'click'
      assert_content 'elided: [...];'

      # Replacement
      select_text 'content to replace'
      find('[title="replace text"]').trigger 'click'
      fill_in placeholder: 'Enter replacement text...', with: 'replacement content'
      click_link 'Save'
      assert_content 'replaced: [replacement content];'

      # Comments
      select_text 'content to comment'
      find('[title="annotate"]').trigger 'click'
      fill_in placeholder: 'Comments...', with: 'comment content'
      click_link 'Save'
      find('.icon.icon-adder-annotate', visible: true).click
      assert_content 'comment content'

      sleep 1.second # TODO: The JS is updating this on a setInterval.

      # Annotations are still visible when logged out
      click_link 'sign out'

      assert_link 'sign in'
      assert_content "#{public_text.name} by #{user.attribution}"

      find('.highlight-hex-ffee00').assert_text 'content to highlight'
      assert_content 'elided: [...];'
      assert_content 'replaced: [replacement content];'
      find('.icon.icon-adder-annotate', visible: true).click
      assert_content 'comment content'
    end

    scenario 'creating a text' do
      sign_in users(:verified_student)

      visit search_all_path

      # TODO: make this more accessible
      within '#create_all_popup' do
        click_link 'Text'
      end

      assert_content 'Add New Text'

      fill_in 'Name', with: text_name = "Test public text - #{random_token}"
      # TODO: There are two fields with label 'Description'
      # TODO: description replaces '-' with '–'
      fill_in 'text_block[description]', with: text_desc = "Test public description: #{random_token}"
      fill_in 'Content', with: text_content = "Test public content - #{random_token}"

      click_button 'Save'

      assert_content 'Text Block was successfully created'
      assert_content text_name
      assert_text text_desc
      assert_content text_content

      text_path = page.current_path
      sign_out
      visit text_path

      assert_content 'sign in'
      assert_content text_name
    end

    scenario 'responding to a text', js: true do
      sign_in users(:verified_student)
      visit text_block_path text_blocks(:text_to_respond)

      find('#responses textarea').set 'Test response text'
      click_link 'Submit'
      assert_content 'Thanks for your response!'

      sign_out

      sign_in users(:verified_professor)
      visit text_block_path text_blocks(:text_to_respond)

      assert_content 'Responses'
      assert_content 'Test response text'
    end
    scenario 'editing a text', js: true do
      sign_in users(:verified_professor)
      visit text_block_path text_blocks(:collaged_text)

      click_link 'EDIT TEXT INFORMATION'

      execute_script "tinyMCE.activeEditor.setContent('#{updated_text = 'This is some updated text.'}');"
      click_button 'Save'
      assert_content 'Text Block was successfully updated.'
      assert_content updated_text
    end
  end
end
