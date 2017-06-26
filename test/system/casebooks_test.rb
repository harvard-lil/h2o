require 'application_system_test_case'

class CasebookSystemTest < ApplicationSystemTestCase
  describe 'as an anonymous visitor' do
    scenario 'viewing a casebook', solr: true do
      visit casebook_path casebook = content_nodes(:public_casebook)
      assert_content casebook.title

      click_link (section_1 = content_nodes(:public_casebook_section_1)).title
      assert_content section_1.headnote

      click_link (resource_1 = content_nodes(:'public_casebook_section_1.1')).resource.short_name
      assert_content resource_1.headnote
      assert_content resource_1.resource.title
      assert_content resource_1.resource.content
    end
  end


  describe 'as a registered user' do
    before do
      sign_in @user = users(:verified_professor)
    end

    scenario 'creating a casebook', solr: true do
      visit root_path

      click_link 'Create casebook'

      fill_in 'Title', with: 'Test casebook title'
      fill_in 'Subtitle', with: 'Test casebook subtitle'
      fill_in 'Headnote', with: 'Test casebook headnote'

      click_button 'Save changes'

      assert_content 'Test casebook title'
      assert_content 'Test casebook subtitle'
      assert_content 'Test casebook headnote'

      assert_content 'This casebook has no content yet.'
      click_button 'Click here to add a section.'

      fill_in 'Title', with: 'Test Section One'
      click_button 'Save changes'

      assert_content 'Test Section One'
      assert_content 'This section has no content yet.'

      click_link 'Click here to add a resource.'

      assert_content 'Add a resource to this section'
      assert_content 'Search for resource'

      case_to_find = cases(:public_case_1)
      fill_in 'q', with: "\"#{case_to_find.short_name}\""
      click_button 'Search'

      assert_content case_to_find.title
      click_button 'Add to section'
    end

    scenario 'reordering casebook contents', js: true do
      casebook = content_nodes(:public_casebook)
      resource = content_nodes(:'public_casebook_section_1.1')

      visit casebook_section_index_path casebook

      assert_content "1.1 #{resource.resource.short_name}"
      simulate_drag_drop '.listing[data-ordinals="1.1"]', '.table-of-contents > .listing-wrapper:last-child', position: :bottom

      assert_content "2.1 #{resource.resource.short_name}"
    end

    scenario 'annotating a casebook', js: true do
      skip
      ## TODO this broke after .less -> .scss change
      casebook = content_nodes(:public_casebook)
      resource = content_nodes(:'public_casebook_section_1.2')

      visit casebook_section_path casebook, resource

      select_text 'content to highlight'
      sleep 0.1
      find('a[data-annotate-action=highlight]').click

      assert_selector('.annotate.highlighted')
      find('.annotate.highlighted').assert_text 'content to highlight'

      select_text 'content to elide'
      sleep 0.1
      find('a[data-annotate-action=elide]').click

      assert_no_content 'content to elide'
      assert_content 'elided: Annotate'

      visit casebook_section_path casebook, resource

      find('.annotate.highlighted').assert_text 'content to highlight'
      assert_content 'elided: Annotate'
    end
  end
end
