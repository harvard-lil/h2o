require 'application_system_test_case'

class AnnotationsSystemTest < ApplicationSystemTestCase

  describe 'as an anonymous visitor' do
    scenario 'cannot annotate a resource', js: true do
      casebook = content_nodes(:public_casebook)
      resource = content_nodes(:public_casebook_section_1_2)

      visit resource_path casebook, resource
      assert_content resource.title

      select_text 'content to highlight'
      sleep 0.1
      refute_selector('a[data-annotation-type=highlight]') # annotation menu does not pop up
    end
  end


  describe 'annotating a resource as a registered user' do
    before do
      sign_in @user = users(:verified_professor)
      visit annotate_resource_path casebook, resource
    end

    let (:casebook) { content_nodes(:draft_casebook) }
    let (:resource) { content_nodes(:'draft_casebook_section_1_2') }

    scenario 'highlighting', js: true do
      select_text 'content to highlight'
      sleep 0.1
      find('a[data-annotation-type=highlight]').click

      assert_selector('.annotate.highlighted')
      find('.annotate.highlighted').assert_text 'content to highlight'
    end

    scenario 'eliding', js: true do
      select_text 'content to elide'
      sleep 0.1
      find('a[data-annotation-type=elide]').click

      assert_no_content 'content to elide'
      assert_content 'elided: ✎;'
    end

    scenario 'replacement', js: true do
      select_text 'content to replace'
      # sleep 0.1
      find('a[data-annotation-type=replace]').click


      binding.pry

      find('.replacement').text = 'new replacement text'

      click_button 'Enter replacement text'
      # puts current_url
      # require 'pry'; binding.pry

      assert_no_content 'content to replace'
      assert_content 'elided: ✎;'
    end

    scenario 'adding a link', js: true do
    end

    scenario 'adding a note', js: true do
    end

    scenario 'deleting an annotation', js: true do
    end

  end
end
