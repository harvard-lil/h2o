require "test_helper"

feature 'texts' do
  # FYI texts are called TextBlocks
  describe 'as an anonymous user' do
    scenario 'browsing texts' do
      # public texts are visible
      # non-public texts are not visible
    end
    scenario 'searching for a text' do
      # this might take some fiddling with to make Solr play nice
    end
    scenario 'reading a text' do
      # content visible
      # metadata visible
      # annotations are visible
    end
  end
  describe 'as a registered user' do
    scenario 'browsing, searching, and reading cases' do
      # DRY stuff from above
      # can see private cases that belong to user
    end

    scenario 'annotating a text', js: true do
      sign_in user = users(:verified_student)
      visit text_block_path public_text = text_blocks(:public_text_to_annotate)

      click_link 'Clone and Annotate'
      assert_xpath "//input[@value='#{public_text.name}']"

      # TODO: make mce tests more intuitive than this
      annotated_desc = "Test annotated case desc: #{random_token}"
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

      visit root_path

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
    scenario 'creating rich content in a text', js: true do

    end
  end
end
