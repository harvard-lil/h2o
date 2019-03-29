require "application_system_test_case"

class Content::NodeDecoratorTest < ApplicationSystemTestCase
  describe 'draft of casebook without a published parent' do
    describe 'in draft mode of casebook that does not have a published parent' do
      before do
        sign_in @user = users(:verified_professor)

        @casebook = content_nodes(:draft_casebook)
        @section = content_nodes(:draft_casebook_section_1)
        @resource = content_nodes(:draft_resource_1)
      end

      it 'renders casebook buttons' do
        visit layout_casebook_path @casebook

        assert_content "Publish"
        assert_content "Preview"
        assert_content "Add Resource"
        assert_content "Add Section"
        assert_content "Export"
        assert_content "Save"
        assert_content "Cancel"
      end

      it 'renders section buttons' do
        visit layout_section_path @casebook, @section

        assert_content "Preview"
        assert_content "Add Resource"
        assert_content "Add Section"
        assert_content "Export"
        assert_content "Save"
        assert_content "Cancel"
      end

      it 'renders resource buttons in edit' do
        visit resource_path @casebook, @resource

        assert_content "Preview"
        assert_content "Export"
        assert_content "Save"
        assert_content "Cancel"
      end
    end

    describe 'in preview mode ' do
      before do
        sign_in @user = users(:verified_professor)

        @casebook = content_nodes(:draft_casebook)
        @section = content_nodes(:draft_casebook_section_1)
        @resource = content_nodes(:draft_resource_1)
      end

      it 'renders casebook buttons' do
        visit casebook_path @casebook 

        assert_content "Publish"
        assert_content "Revise"
        assert_content "Export"
        assert_content "Clone"
      end

      it 'renders section buttons' do
        visit section_path @casebook, @section

        assert_content "Revise"
        assert_content "Clone"
      end

      it 'renders resource buttons' do
        visit resource_path @casebook, @resource

        assert_content "Revise"
        assert_content "Clone"
      end
    end

    describe 'in published mode as casebook creator' do
      before do
        sign_in @user = users(:verified_professor)

        @casebook = content_nodes(:public_casebook)
        @section = content_nodes(:public_casebook_section_1)
        @resource = content_nodes(:public_casebook_section_1_1)
      end

      it 'renders casebook buttons' do
        visit casebook_path @casebook

        assert_content "Revise"
        assert_content "Clone"
        assert_content "Export"
      end

      it 'renders section buttons' do
        visit section_path @casebook, @section

        assert_content "Revise"
        assert_content "Clone"
        assert_content "Export"
      end

      it 'renders resource buttons' do
        visit resource_path @casebook, @resource
        dom = Nokogiri::HTML(decorated_content.action_buttons)

        assert_content "Revise"
        assert_content "Clone"
        assert_content "Export"
      end
    end
  end

  describe 'published casebook with a logged in user' do
    before do
      sign_in @user = users(:verified_student)

      @casebook = content_nodes(:public_casebook)
      @section = content_nodes(:public_casebook_section_1)
      @resource = content_nodes(:public_casebook_section_1_1)
    end

    it 'renders casebook buttons' do
      visit casebook_path @casebook

      assert_content "Clone"
      assert_content "Export"
    end

    it 'renders section buttons' do
      visit section_path @casebook, @section

      assert_content "Clone"
      assert_content "Export"
    end

    it 'renders resource buttons' do
      visit resource_path @casebook, @resource

      assert_content "Clone"
      assert_content "Export"
    end
  end
end
