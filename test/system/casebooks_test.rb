# coding: utf-8
require "application_system_test_case"

class CasebookSystemTest < ApplicationSystemTestCase

  describe "as an anonymous visitor" do
    scenario "viewing a casebook", solr: true, js: true do
      casebook = content_nodes(:public_casebook)
      section_1 = content_nodes(:public_casebook_section_1)
      resource_1 = content_nodes(:public_casebook_section_1_1)

      visit casebook_path casebook
      assert_content casebook.title

      click_link section_1.title

      click_link resource_1.resource.name_abbreviation
      assert_content resource_1.resource.title
      assert_content resource_1.resource.content
    end
  end

  describe "as a registered user" do
    before do
      sign_in @user = users(:verified_professor)
    end

    scenario "creating a casebook", solr: true, js: true do
      visit root_path

      find(".create-casebook").click
      click_link "Make a New Casebook"

      fill_in "content_casebook_title", with: "Test casebook title"
      fill_in "content_casebook_subtitle", with: "Test casebook subtitle"

      click_on "Save"

      assert_equal (find("#content_casebook_title").value), "Test casebook title"
      assert_equal (find("#content_casebook_subtitle").value), "Test casebook subtitle"

      assert_content "This casebook has no content yet."
      click_button "Add Section"

      fill_in "content_section_title", with: "Test Section One"
      click_link "Save"

      visit layout_casebook_path Content::Casebook.last
      click_link "Test Section One"
      assert_content "This section has no content yet."

      click_link "Add Resource"

      case_to_find = cases(:public_case_1)
      within ".case-search" do
        fill_in "q", with: "\"#{case_to_find.name_abbreviation}\""
        click_button "Search"
      end

      find(".results-entry .title").click
    end

    describe "reordering casebook contents" do
      let (:casebook) { content_nodes(:draft_casebook) }
      let (:resource_1) { content_nodes(:draft_resource_1) }
      let (:resource_2) { content_nodes(:draft_resource_2) }
      let (:section_1) { content_nodes(:draft_casebook_section_1) }
      let (:section_2) { content_nodes(:draft_casebook_section_2) }

      before do
        visit layout_casebook_path casebook
      end

      scenario "resource down into a section", js: true do
        assert_content "This casebook is a draft"
        assert_content "1.1\n#{resource_1.resource.name_abbreviation}"

        simulate_drag_drop '.listing[data-ordinals="1.1"]', '.table-of-contents > .listing-wrapper:last-child', position: :bottom
        sleep 0.3

        visit casebook_path casebook
        assert_content "2.1\n#{resource_1.resource.name_abbreviation}"
        assert_content "1.1\n#{resource_2.resource.name_abbreviation}"
      end

      scenario "section above top section", js: true do
        assert_content "This casebook is a draft"
        assert_content "2\n#{section_2.title}"

        simulate_drag_drop '.listing[data-ordinals="2"]', '.table-of-contents > .listing-wrapper', position: :top
        sleep 0.3

        visit casebook_path casebook
        assert_content "1\n#{section_2.title}"
        assert_content "2\n#{section_1.title}"
      end
    end

    scenario "cloning a casebook of another user", js: true do
      casebook = content_nodes(:student_casebook)
      visit casebook_path casebook
      click_button "Clone"
      sleep 1

      visit root_path

      assert_content casebook.title
      assert_content "Original author: #{casebook.owner.attribution}"
    end

    scenario "creating a draft from a published casebook", js: true do
      casebook = content_nodes(:public_casebook)
      visit casebook_path casebook

      click_link "Revise"
      sleep 1

      visit root_path

      assert_content casebook.title
      assert_content "This casebook has unpublished changes."
    end

    scenario "deleting a resource in a draft does not break ability to edit published casebook resource", js: true do
      published_casebook = content_nodes(:published_casebook)
      draft_casebook = content_nodes(:draft_merge_casebook)

      update_ancestry(published_casebook, draft_casebook)

      visit casebook_path published_casebook
      assert_selector('.listing-wrapper', count: 4)

      visit casebook_path draft_casebook
      assert_selector('.listing-wrapper', count: 4)

      draft_casebook.resources.first.destroy!

      visit resource_path published_casebook, published_casebook.resources.first

      click_link "Return to Draft"
    end
  end
end
