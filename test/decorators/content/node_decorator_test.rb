require "application_system_test_case"

class Content::NodeDecoratorTest < ApplicationSystemTestCase
  describe 'draft of casebook without a published parent' do
    before do
      sign_in @user = users(:verified_professor)

      @casebook = content_nodes(:draft_casebook)
      @section = content_nodes(:draft_casebook_section_1)
      @resource = content_nodes(:draft_resource_1)
    end

    describe 'draft mode' do
      it 'casebook actions' do
        visit layout_casebook_path @casebook

        assert_content "Publish"
        assert_content "Preview"
        assert_content "Add Resource"
        assert_content "Add Section"
        assert_content "Export"
        assert_content "Save"
        assert_content "Cancel"
      end

      it 'section actions' do
        visit layout_section_path @casebook, @section

        assert_content "Preview"
        assert_content "Add Resource"
        assert_content "Add Section"
        assert_content "Export"
        assert_content "Save"
        assert_content "Cancel"
      end

      it 'resource actions in edit' do
        visit resource_path @casebook, @resource

        assert_content "Preview"
        assert_content "Export"
        assert_content "Save"
        assert_content "Cancel"
      end
    end

    describe 'preview mode ' do
      it 'casebook actions' do
        visit casebook_path @casebook 

        assert_content "Publish"
        assert_content "Revise"
        assert_content "Export"
        assert_content "Clone"
      end

      it 'section actions' do
        visit section_path @casebook, @section

        assert_content "Revise"
        assert_content "Clone"
      end

      it 'resource actions' do
        visit resource_path @casebook, @resource

        assert_content "Revise"
        assert_content "Clone"
      end
    end

    describe 'published mode' do
      it 'casebook actions' do
        visit casebook_path @casebook

        assert_content "Revise"
        assert_content "Clone"
        assert_content "Export"
      end

      it 'section actions' do
        visit section_path @casebook, @section

        assert_content "Revise"
        assert_content "Clone"
        assert_content "Export"
      end

      it 'resource actions' do
        visit resource_path @casebook, @resource
        dom = Nokogiri::HTML(decorated_content.action_buttons)

        assert_content "Revise"
        assert_content "Clone"
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
    end

    describe 'draft mode' do
      it 'casebook actions' do
        visit layout_casebook_path @casebook

        assert_content "Publish Changes"
        assert_content "Preview"
        assert_content "Add Resource"
        assert_content "Add Section"
        assert_content "Export"
        assert_content "Save"
        assert_content "Cancel"
        refute_content "Clone"
      end

      it 'section actions' do
        visit layout_section_path @casebook, @section

        assert_content "Preview"
        assert_content "Add Resource"
        assert_content "Add Section"
        assert_content "Export"
        assert_content "Save"
        assert_content "Cancel"
        refute_content "Clone"
      end

      it 'resource actions in edit' do
        visit resource_path @casebook, @resource

        assert_content "Preview"
        assert_content "Export"
        assert_content "Save"
        assert_content "Cancel"
        refute_content "Clone"
      end
    end

    describe 'preview mode ' do
      it 'casebook actions' do
        visit casebook_path @casebook 

        assert_content "Publish Changes"
        assert_content "Return to Draft"
        assert_content "Export"
        refute_content "Clone"
      end

      it 'section actions' do
        visit section_path @casebook, @section

        assert_content "Return to Draft"
        assert_content "Export"
        refute_content "Clone"
      end

      it 'resource actions' do
        visit resource_path @casebook, @resource

        assert_content "Revise"
        refute_content "Clone"
      end
    end

    describe 'published mode' do
      it 'casebook actions' do
        visit casebook_path @casebook

        assert_content "Return to Draft"
        assert_content "Clone"
        assert_content "Export"
      end

      it 'section actions' do
        visit section_path @casebook, @section

        assert_content "Return to Draft"
        assert_content "Clone"
        assert_content "Export"
      end

      it 'resource actions' do
        visit resource_path @casebook, @resource
        dom = Nokogiri::HTML(decorated_content.action_buttons)

        assert_content "Return to Draft"
        assert_content "Clone"
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

    it 'casebook actions' do
      visit casebook_path @casebook

      assert_content "Clone"
      assert_content "Export"
    end

    it 'section actions' do
      visit section_path @casebook, @section

      assert_content "Clone"
      assert_content "Export"
    end

    it 'resource actions' do
      visit resource_path @casebook, @resource

      assert_content "Clone"
      assert_content "Export"
    end
  end

  describe 'published casebook with an anonymous user' do
    before do
      @casebook = content_nodes(:public_casebook)
      @section = content_nodes(:public_casebook_section_1)
      @resource = content_nodes(:public_casebook_section_1_1)
    end

    describe 'casebook actions' do
      assert_content "Clone"
      assert_content "Export"
    end

    describe 'section actions' do
      assert_content "Clone"
      assert_content "Export"
    end

    describe 'resource actions' do
      assert_content "Clone"
      assert_content "Export"
    end
  end
end
