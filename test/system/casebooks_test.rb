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
      click_link resource_1.title

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
      click_button "Save"

      visit layout_casebook_path Content::Casebook.last
      click_link "Test Section One"
      assert_content "This section has no content yet."

      click_button "Add Resource"

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
        assert_content "1.1\n#{resource_1.title}"

        simulate_drag_drop '.listing[data-ordinals="1.1"]', '.table-of-contents > .listing-wrapper:last-child', position: :bottom
        sleep 0.3

        visit casebook_path casebook
        assert_content "2.1\n#{resource_1.title}"
        assert_content "1.1\n#{resource_2.title}"
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
      @published_casebook = content_nodes(:published_casebook)
      @draft_casebook = content_nodes(:draft_merge_casebook)
      @published_resource = content_nodes(:published_casebook_section_2)
      @draft_resource = content_nodes(:draft_merge_section_2)

      assert_equal @published_resource.ordinals, @draft_resource.ordinals

      update_ancestry(@published_casebook, @draft_casebook)
      
      visit resource_path @published_casebook, @published_resource

      click_link "Return to Draft"

      assert_content @draft_casebook.title
      assert_content @draft_casebook.headnote

      visit resource_path @published_casebook, @published_resource
      @draft_resource.destroy

      click_link "Return to Draft"

      assert_content @draft_casebook.title
      assert_content @draft_casebook.headnote
    end
  end

  describe "action buttons" do
    describe 'casebook without a published parent' do
      before do
        sign_in @user = users(:verified_professor)

        @casebook = content_nodes(:draft_casebook)
        @section = content_nodes(:draft_casebook_section_1)
        @resource = content_nodes(:draft_resource_1)
      end

      describe 'draft mode' do
        scenario 'casebook actions' do
          visit layout_casebook_path @casebook

          assert_button "Publish"
          assert_content "Preview"
          assert_button "Add Resource"
          assert_button "Add Section"
          assert_content "Export"
          assert_button "Save"
          assert_content "Cancel"
        end

        scenario 'section actions' do
          visit layout_section_path @casebook, @section
          assert_content "Preview"
          assert_button "Add Resource"
          assert_button "Add Section"
          assert_content "Export"
          assert_button "Save"
          assert_content "Cancel"
        end

        scenario 'resource actions for link annotation' do
          visit edit_resource_path @casebook, @resource

          assert_content "Preview"
          assert_content "Export"
          assert_button "Save"
          assert_content "Cancel"
        end

        scenario 'resource actions for annotation' do
          visit edit_resource_path @casebook, @resource
          assert_content "Preview"
          assert_content "Export"
          assert_button "Save"
          assert_content "Cancel"

          visit annotate_resource_path @casebook, @resource
          assert_content "Preview"
          assert_content "Export"
          refute_button "Save"
          refute_content "Cancel"
        end
      end

      describe 'preview mode ' do
        scenario 'casebook actions' do
          visit casebook_path @casebook 

          assert_button "Publish"
          assert_content "Revise"
          assert_content "Export"
          assert_button "Clone"
        end

        scenario 'section actions' do
          visit section_path @casebook, @section

          assert_content "Revise"
          assert_button "Clone"
        end

        scenario 'resource actions' do
          visit resource_path @casebook, @resource

          assert_content "Revise"
          assert_button "Clone"
        end
      end

      describe 'published mode' do
        before do
          @casebook.update(public: true)
        end

        scenario 'casebook actions' do
          visit casebook_path @casebook

          assert_content "Revise"
          assert_button "Clone"
          assert_content "Export"
        end

        scenario 'section actions' do
          visit section_path @casebook, @section

          assert_content "Revise"
          assert_button "Clone"
          assert_content "Export"
        end

        scenario 'resource actions' do
          visit resource_path @casebook, @resource

          assert_content "Revise"
          assert_button "Clone"
          assert_content "Export"
        end
      end
    end

    describe 'draft of casebook with a published parent' do
      before do
        sign_in @user = users(:verified_professor)

        @casebook = content_nodes(:draft_merge_casebook)
        @section = content_nodes(:draft_merge_section)
        @resource = content_nodes(:draft_merge_section_1)

        @parent_casebook = content_nodes(:published_casebook)
        @parent_section = content_nodes(:published_casebook_section_3)
        @parent_resource = content_nodes(:published_casebook_section_1)

        update_ancestry(@parent_casebook, @casebook)
      end

      describe 'draft mode' do
        scenario 'casebook actions' do
          visit layout_casebook_path @casebook
          assert_button "Publish Changes"
          assert_content "Preview"
          assert_button "Add Resource"
          assert_button "Add Section"
          assert_content "Export"
          assert_button "Save"
          assert_content "Cancel"
          refute_button "Clone"
        end

        scenario 'section actions' do
          visit layout_section_path @casebook, @section
          assert_content "Preview"
          assert_button "Add Resource"
          assert_button "Add Section"
          assert_content "Export"
          assert_button "Save"
          assert_content "Cancel"
          refute_button "Clone"
        end

        scenario 'resource actions' do
          visit edit_resource_path @casebook, @resource
          assert_content "Preview"
          assert_content "Export"
          assert_button "Save"
          assert_content "Cancel"
        end
      end

      describe 'preview mode ' do
        scenario 'casebook actions' do
          visit casebook_path @casebook 
          assert_button "Publish Changes"
          assert_content "Return to Draft"
          assert_content "Export"
          refute_button "Clone"
        end

        scenario 'section actions' do
          visit section_path @casebook, @section
          assert_content "Return to Draft"
          assert_content "Export"
          refute_button "Clone"
        end

        scenario 'resource actions' do
          visit resource_path @casebook, @resource
          assert_content "Return to Draft"
          refute_button "Clone"
        end
      end

      describe 'published mode' do
        scenario 'casebook actions' do
          visit casebook_path @parent_casebook
          assert_content "Return to Draft"
          assert_button "Clone"
          assert_content "Export"
        end

        scenario 'section actions' do
          visit section_path @parent_casebook, @parent_section
          assert_content "Return to Draft"
          assert_button "Clone"
          assert_content "Export"
        end

        scenario 'resource actions' do
          visit resource_path @parent_casebook, @parent_resource
          assert_content "Return to Draft"
          assert_button "Clone"
          assert_content "Export"
        end
      end
    end

    describe 'published casebook with a logged in user that is not a collaborator' do
      before do
        sign_in @user = users(:verified_student)

        @casebook = content_nodes(:public_casebook)
        @section = content_nodes(:public_casebook_section_1)
        @resource = content_nodes(:public_casebook_section_1_1)
      end

      scenario 'casebook actions' do
        visit casebook_path @casebook
        assert_button "Clone"
        assert_content "Export"
      end

      scenario 'section actions' do
        visit section_path @casebook, @section
        assert_button "Clone"
        assert_content "Export"
      end

      scenario 'resource actions' do
        visit resource_path @casebook, @resource
        assert_button "Clone"
        assert_content "Export"
      end
    end

    describe 'published casebook with an anonymous user' do
      before do
        @casebook = content_nodes(:public_casebook)
        @section = content_nodes(:public_casebook_section_1)
        @resource = content_nodes(:public_casebook_section_1_1)
      end

      scenario 'casebook actions' do
        visit casebook_path @casebook
        refute_button "Clone"
        assert_content "Export"
      end

      scenario 'section actions' do
        visit section_path @casebook, @section
        refute_button "Clone"
        assert_content "Export"
      end

      scenario 'resource actions' do
        visit resource_path @casebook, @resource
        refute_button "Clone"
        assert_content "Export"
      end
    end
  end
end
