require 'application_system_test_case'

class CasebookSystemTest < ApplicationSystemTestCase
  describe 'as an anonymous visitor' do
    scenario 'viewing a casebook', solr: true do
      casebook = content_nodes(:public_casebook)
      section_1 = content_nodes(:public_casebook_section_1)
      resource_1 = content_nodes(:'public_casebook_section_1.1')

      visit casebook_path casebook
      assert_content casebook.title

      click_link section_1.title
      assert_content section_1.headnote

      click_link resource_1.resource.short_name
      assert_content resource_1.headnote
      assert_content resource_1.resource.title
      assert_content resource_1.resource.content
    end
  end


  describe 'as a registered user' do
    before do
      sign_in @user = users(:verified_professor)
    end

    scenario 'creating a casebook', solr: true, js: true do
      visit root_path

      find('.create-casebook').trigger 'click'
      click_link 'From Scratch'

      fill_in 'content_casebook_title', with: 'Test casebook title'
      fill_in 'content_casebook_subtitle', with: 'Test casebook subtitle'
      fill_in 'content_casebook_headnote', with: 'Test casebook headnote'

      click_button 'Save'

      assert_content 'Test casebook title'
      assert_content 'Test casebook subtitle'
      assert_content 'Test casebook headnote'

      assert_content 'This casebook has no content yet.'
      click_button 'Click here to add a section.'

      fill_in 'content_section_title', with: 'Test Section One'
      click_button 'Save'

      visit layout_casebook_path Content::Casebook.last
      click_link 'Test Section One'
      assert_content 'This section has no content yet.'

      click_link 'Click here to add a resource.'

      case_to_find = cases(:public_case_1)
      within '.case-search' do
        fill_in 'q', with: "\"#{case_to_find.short_name}\""
        click_button 'Search'
      end

      find('.results-entry .title').click
    end

    scenario 'reordering casebook contents', js: true do
      casebook = content_nodes(:draft_casebook)
      resource = content_nodes(:'draft_casebook_section_1.1')

      visit layout_casebook_path casebook
      
      click_link 'Revise'

      assert_content 'This casebook is a draft'
      assert_content "1.1 #{resource.resource.short_name}"
      simulate_drag_drop '.listing[data-ordinals="1.1"]', '.table-of-contents > .listing-wrapper:last-child', position: :bottom

      assert_content "2.1 #{resource.resource.short_name}"
    end

    scenario 'annotating a casebook', js: true do
      casebook = content_nodes(:draft_casebook)
      resource = content_nodes(:'draft_casebook_section_1.2')

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
      assert_content 'elided: Annotate'

      visit annotate_resource_path casebook, resource

      find('.annotate.highlighted').assert_text 'content to highlight'
      assert_content 'elided: Annotate'
    end
  end
end
