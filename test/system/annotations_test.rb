require 'application_system_test_case'

class AnnotationsSystemTest < ApplicationSystemTestCase

  describe 'as an anonymous visitor' do
    scenario 'cannot annotate a resource', js: true do
      casebook = content_nodes(:public_casebook)
      resource = content_nodes(:public_casebook_section_1_2)

      visit resource_path casebook, resource
      assert_content resource.title

      select_text 'content to highlight'
      refute_selector('a[data-annotation-type=highlight]') # annotation menu does not pop up
    end
  end


  describe 'annotating a resource as a registered user' do
    let (:casebook) { content_nodes(:draft_casebook) }
    let (:resource) { content_nodes(:'draft_resource_2') }

    before do
      sign_in @user = users(:verified_professor)
      visit annotate_resource_path casebook, resource
    end

    scenario 'highlighting', js: true do
      select_text 'content to highlight'
      find('a[data-annotation-type=highlight]').click

      assert_selector('.annotate.highlighted')
      find('.annotate.highlighted').assert_text 'content to highlight'
    end

    scenario 'eliding', js: true do
      select_text 'content to elide'
      find('a[data-annotation-type=elide]').click

      assert_no_content 'content to elide'
      assert_content 'elided: ✎;'
    end

    scenario 'replacement', js: true do
      select_text 'content to replace'
      find('a[data-annotation-type=replace]').click
      sleep 0.5

      page.execute_script("document.getElementsByClassName('replacement')[0].textContent = 'New Text'")

      sleep 0.1

      assert_content 'New Text'
      # this doesn't actually test saving these annotations because since it's a span you can't fill in text with capybara in a dynamic way and then hit enter, so the save menu does not show up
    end

    scenario 'adding a link', js: true do
      select_text 'content to link'
      find('a[data-annotation-type=link]').click

      fill_in 'link-form', with: 'https://testlink.org'
      find('#link-form').send_keys :enter

      has_link?('content to link', href: 'https://testlink.org')
    end

    scenario 'adding a link without http', js: true do
      select_text 'content to link'
      find('a[data-annotation-type=link]').click

      fill_in 'link-form', with: 'testlink.org'
      find('#link-form').send_keys :enter

      has_link?('content to link', href: 'http://testlink.org')
    end

    scenario 'adding a note', js: true do
      select_text 'content to note'
      find('a[data-annotation-type=note]').click

      fill_in 'note-textarea', with: 'Here is a new note'
      find('.save-note').click

      find('.note-content', text: "Here is a new note") #acts as a assert_content for a span
      assert_selector('.note-content')
    end

    scenario 'deleting an annotation', js: true do
      select_text 'content to note'
      find('a[data-annotation-type=note]').click

      fill_in 'note-textarea', with: 'Here is a new note'
      find('.save-note').click

      click_button 'edit-annotation'
      find('.context-menu').click # click on Remove Note link
      sleep 0.3

      refute_selector('.note-content')
    end
  end
end
