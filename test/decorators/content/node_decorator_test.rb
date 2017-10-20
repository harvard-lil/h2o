require 'test_helper'

class Content::NodeDecoratorTest < ActionView::TestCase
  describe 'in draft mode' do
    before do
      @casebook = content_nodes(:private_casebook)
      @section = content_nodes(:private_casebook_section_1)
      @resource = content_nodes(:private_casebook_resource_1_1)
    end

    it 'renders casebook buttons' do
      decorated_content = @casebook.decorate(context: {action_name: 'layout', casebook: @casebook})
      dom = Nokogiri::HTML(decorated_content.action_buttons)

      has_publish_link?(dom)
      has_preview_link?(dom)
      has_add_resource_link?(dom)
      has_add_section_link?(dom)
      has_export_link?(dom)
      has_clone_link?(dom)
    end

    it 'renders section buttons' do
      decorated_content = @section.decorate(context: {action_name: 'layout', casebook: @casebook, section: @section})
      dom = Nokogiri::HTML(decorated_content.action_buttons)

      has_preview_link?(dom)
      has_add_resource_link?(dom)
      has_add_section_link?(dom)
      has_save_link?(dom)
      has_cancel_link?(dom) 
      has_export_link?(dom)
    end

    it 'renders resource buttons in edit' do
      decorated_content = @section.decorate(context: {action_name: 'edit', casebook: @casebook, 
        section: @section, resource: @resource})
      dom = Nokogiri::HTML(decorated_content.action_buttons)

      has_preview_link?(dom)
      has_save_link?(dom)
      has_cancel_link?(dom)
      has_export_link?(dom)
    end
  end

  describe 'in preview mode' do
    before do
      @casebook = content_nodes(:private_casebook)
      @section = content_nodes(:private_casebook_section_1)
      @resource = content_nodes(:private_casebook_resource_1_1)
    end

    it 'renders casebook buttons' do
      decorated_content = @casebook.decorate(context: {action_name: 'show', casebook: @casebook})
      dom = Nokogiri::HTML(decorated_content.action_buttons)

      has_publish_link?(dom)
      has_revise_link?(dom)
      has_clone_link?(dom)
      has_export_link?(dom)
    end

    it 'renders section buttons' do
      decorated_content = @section.decorate(context: {action_name: 'show', casebook: @casebook, section: @section})
      dom = Nokogiri::HTML(decorated_content.action_buttons)

      has_revise_link?(dom)
      has_clone_link?(dom)
      has_export_link?(dom)
    end

    it 'renders resource buttons' do
      decorated_content = @section.decorate(context: {action_name: 'show', casebook: @casebook, 
        section: @section, resource: @resource})
      dom = Nokogiri::HTML(decorated_content.action_buttons)

      has_revise_link?(dom)
      has_clone_link?(dom)
      has_export_link?(dom)
    end
  end

  describe 'in published mode as casebook creator' do
    #
    ## Authlogic::Session::Activation::NotActivatedError:         Authlogic::Session::Activation::NotActivatedError: You must activate the Authlogic::Session::Base.controller with a controller object before creating objects
    #
    # before do
    #   @casebook = content_nodes(:public_casebook)
    #   @section = content_nodes(:public_casebook_section_1)
    #   @resource = content_nodes(:public_casebook_section_1.1)
    # end

    # it 'renders casebook buttons' do
      # decorated_content = @casebook.decorate(context: {action_name: 'show', casebook: @casebook})
      # dom = Nokogiri::HTML(decorated_content.action_buttons)

      # has_revise_link?(dom)
      # has_clone_link?(dom)
      # has_export_link?(dom)
    # end

    # it 'renders section buttons' do
    #   decorated_content = @section.decorate(context: {action_name: 'show', casebook: @casebook, section: @section})
    #   dom = Nokogiri::HTML(decorated_content.action_buttons)

    #   has_revise_link?(dom)
    #   has_clone_link?(dom)
    #   has_export_link?(dom)
    # end

    # it 'renders resource buttons' do
    #   decorated_content = @section.decorate(context: {action_name: 'show', casebook: @casebook, 
    #   section: @section, resource: @resource})
    #   dom = Nokogiri::HTML(decorated_content.action_buttons)

    #   has_revise_link?(dom)
    #   has_clone_link?(dom)
    #   has_export_link?(dom)
    # end
  end

  describe 'in published mode not as casebook creator' do
    # before do
    #   @casebook = content_nodes(:public_casebook)
    #   @section = content_nodes(:public_casebook_section_1)
    #   @resource = content_nodes(:public_casebook_section_1.1)
    # end

    # it 'renders casebook buttons' do
    #   decorated_content = @casebook.decorate(context: {action_name: 'show', casebook: @casebook})
    #   dom = Nokogiri::HTML(decorated_content.action_buttons)

    #   has_clone_link?(dom)
    #   has_export_link?(dom)
    # end

    # it 'renders section buttons' do
    #   decorated_content = @section.decorate(context: {action_name: 'show', casebook: @casebook, section: @section})
    #   dom = Nokogiri::HTML(decorated_content.action_buttons)

    #   has_clone_link?(dom)
    #   has_export_link?(dom)
    # end

    # it 'renders resource buttons' do
    #   decorated_content = @section.decorate(context: {action_name: 'show', casebook: @casebook, 
    #   section: @section, resource: @resource})
    #   dom = Nokogiri::HTML(decorated_content.action_buttons)

    #   has_clone_link?(dom)
    #   has_export_link?(dom)
    # end
  end

  def has_preview_link?(dom)
    assert_select dom, 'a', text: 'Preview'
  end

  def has_save_link?(dom)
    assert_select dom, 'a', text: 'Save'
  end

  def has_cancel_link?(dom)
    assert_select dom, 'a', text: 'Cancel'
  end

  def has_publish_link?(dom)
    assert_select dom, 'form', class: 'publish'
  end

  def has_add_resource_link?(dom)
    assert_select dom, 'a', text: 'Add Resource'
  end

  def has_add_section_link?(dom)
    assert_select dom, 'form', class: 'add-section'
  end

  def has_export_link?(dom)
    assert_select dom, 'a', text: 'Export'
  end

  def has_revise_link?(dom)
    assert_select dom, 'a', text: 'Revise'
  end

  def has_clone_link?(dom)
    assert_select dom, 'input.clone-casebook'
  end
end