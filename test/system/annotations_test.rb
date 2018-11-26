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


  describe 'as a registered user' do
    before do
      sign_in @user = users(:verified_professor)
    end

    scenario 'annotating a resource', js: true do
      casebook = content_nodes(:draft_casebook)
      resource = content_nodes(:'draft_casebook_section_1_2')

      visit annotate_resource_path casebook, resource

      select_text 'content to highlight'
      sleep 0.1
      find('a[data-annotation-type=highlight]').click

      assert_selector('.annotate.highlighted')
      find('.annotate.highlighted').assert_text 'content to highlight'

      select_text 'content to elide'
      sleep 0.1
      find('a[data-annotation-type=elide]').click

      assert_no_content 'content to elide'
      assert_content 'elided: ✎;'

      visit annotate_resource_path casebook, resource

      find('.annotate.highlighted').assert_text 'content to highlight'
      assert_content 'elided: ✎;'
    end
  end
end
