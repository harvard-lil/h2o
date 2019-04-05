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

      assert_button "Publish"
      assert_button "Preview"
      assert_button "Add Resource"
      assert_button "Add Section"
      assert_button "Export"
      assert_button "Save"
      assert_button "Cancel"
    end

    it 'section actions' do
      visit layout_section_path @casebook, @section

      assert_button "Preview"
      assert_button "Add Resource"
      assert_button "Add Section"
      assert_button "Export"
      assert_button "Save"
      assert_button "Cancel"
    end

    it 'resource actions in edit' do
      visit resource_path @casebook, @resource

      assert_button "Preview"
      assert_button "Export"
      assert_button "Save"
      assert_button "Cancel"
    end
  end

  describe 'preview mode ' do
    it 'casebook actions' do
      visit casebook_path @casebook 

      assert_button "Publish"
      assert_button "Revise"
      assert_button "Export"
      assert_button "Clone"
    end

    it 'section actions' do
      visit section_path @casebook, @section

      assert_button "Revise"
      assert_button "Clone"
    end

    it 'resource actions' do
      visit resource_path @casebook, @resource

      assert_button "Revise"
      assert_button "Clone"
    end
  end

  describe 'published mode' do
    it 'casebook actions' do
      visit casebook_path @casebook

      assert_button "Revise"
      assert_button "Clone"
      assert_button "Export"
    end

    it 'section actions' do
      visit section_path @casebook, @section

      assert_button "Revise"
      assert_button "Clone"
      assert_button "Export"
    end

    it 'resource actions' do
      visit resource_path @casebook, @resource
      dom = Nokogiri::HTML(decorated_content.action_buttons)

      assert_button "Revise"
      assert_button "Clone"
      assert_button "Export"
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

      assert_button "Publish Changes"
      assert_button "Preview"
      assert_button "Add Resource"
      assert_button "Add Section"
      assert_button "Export"
      assert_button "Save"
      assert_button "Cancel"
      refute_button "Clone"
    end

    it 'section actions' do
      visit layout_section_path @casebook, @section

      assert_button "Preview"
      assert_button "Add Resource"
      assert_button "Add Section"
      assert_button "Export"
      assert_button "Save"
      assert_button "Cancel"
      refute_button "Clone"
    end

    it 'resource actions in edit' do
      visit resource_path @casebook, @resource

      assert_button "Preview"
      assert_button "Export"
      assert_button "Save"
      assert_button "Cancel"
      refute_button "Clone"
    end
  end

  describe 'preview mode ' do
    it 'casebook actions' do
      visit casebook_path @casebook 

      assert_button "Publish Changes"
      assert_button "Return to Draft"
      assert_button "Export"
      refute_button "Clone"
    end

    it 'section actions' do
      visit section_path @casebook, @section

      assert_button "Return to Draft"
      assert_button "Export"
      refute_button "Clone"
    end

    it 'resource actions' do
      visit resource_path @casebook, @resource

      assert_button "Revise"
      refute_button "Clone"
    end
  end

  describe 'published mode' do
    it 'casebook actions' do
      visit casebook_path @casebook

      assert_button "Return to Draft"
      assert_button "Clone"
      assert_button "Export"
    end

    it 'section actions' do
      visit section_path @casebook, @section

      assert_button "Return to Draft"
      assert_button "Clone"
      assert_button "Export"
    end

    it 'resource actions' do
      visit resource_path @casebook, @resource
      dom = Nokogiri::HTML(decorated_content.action_buttons)

      assert_button "Return to Draft"
      assert_button "Clone"
      assert_button "Export"
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

    assert_button "Clone"
    assert_button "Export"
  end

  it 'section actions' do
    visit section_path @casebook, @section

    assert_button "Clone"
    assert_button "Export"
  end

  it 'resource actions' do
    visit resource_path @casebook, @resource

    assert_button "Clone"
    assert_button "Export"
  end
end

describe 'published casebook with an anonymous user' do
  before do
    @casebook = content_nodes(:public_casebook)
    @section = content_nodes(:public_casebook_section_1)
    @resource = content_nodes(:public_casebook_section_1_1)
  end

  describe 'casebook actions' do
    assert_button "Clone"
    assert_button "Export"
  end

  describe 'section actions' do
    assert_button "Clone"
    assert_button "Export"
  end

  describe 'resource actions' do
    assert_button "Clone"
    assert_button "Export"
  end
end
