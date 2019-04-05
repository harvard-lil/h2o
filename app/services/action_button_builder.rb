class ActionButtonBuilder
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper

  attr_reader :action, :casebook, :section, :resource

  def initialize(casebook, section, resource, action)
    @action = action
    @casebook = casebook
    @section = section
    @resource = resource
  end

  def perform(actions)
    # Turns the action symbols into methods and collect all the results
    transcribed_actions = actions.map { |action| self.method(action).call}
  end

  private

  def create_resource_draft
    { link_to: true, text: I18n.t("content.actions.revise"), path: create_draft_resource_path(casebook, resource), class: "action edit one-line create-draft" }
  end

  def annotate_resource_draft
    { link_to: true, text: I18n.t("content.actions.revise-draft"), path: annotate_resource_path(draft, draft_resource), class: "action edit one-line" }
  end

  def annotate_resource
    { link_to: true, text: I18n.t("content.actions.revise-draft"), path: annotate_resource_path(casebook, resource), class: "action edit one-line" }
  end

  def clone_resource
    { link_to: true, text: I18n.t("content.actions.clone"), path: clone_resource_path(casebook, resource), class: "action clone-casebook" }
  end

  def preview_resource
    { link_to: true, text: I18n.t("content.actions.preview"), path: resource_path(casebook, resource), class: "action one-line preview" }
  end

  def save_resource
    { link_to: true, text: I18n.t("content.actions.save"), path: "", class: "action one-line save submit-edit-details" }
  end

  def cancel_resource
    { link_to: true, text: I18n.t("content.actions.cancel"), path: "", class: "action one-line cancel" }
  end

  #############
  ## Section

  def create_section_draft
    { link_to: true, text: I18n.t("content.actions.revise"), path: edit_section_path(casebook, section), class: "action edit one-line create-draft" }
  end

  def revise_section
    { link_to: true, text: I18n.t("content.actions.revise-draft"), path: revise_section_path(casebook, section), class: "action edit one-line" }
  end

  def clone_section
    { link_to: true, text: I18n.t("content.actions.clone"), path: clone_section_path(casebook, section), class: "action clone-casebook" }
  end

  def revise_draft_section
    if has_published_parent
      { link_to: true, text: I18n.t("content.actions.revise-draft"), path: layout_section_path(casebook, section), class: "action edit one-line" }
    else
      { link_to: true, text: I18n.t("content.actions.revise-draft"), path: layout_section_path(draft, draft_section), class: "action edit one-line" }
    end
  end

  def preview_section
    { link_to: true, text: I18n.t("content.actions.preview"), path: section_path(casebook, section), class: "action one-line preview" }
  end

  def save_section
    { button_to: true, text: I18n.t("content.actions.save"), path: "", class: "action one-line save submit-section-details" }
  end

  def cancel_section
    { link_to: true, text: I18n.t("content.actions.cancel"), path: "#", class: "action one-line cancel" }
  end

  ############
  ## Casebook

  def publish_changes_to_casebook
    { button_tag: true, text: I18n.t("content.actions.publish-changes"), name: nil, type: "button", class:  "action publish one-line"}
  end

  def publish_casebook
    { button_tag: true, text: I18n.t("content.actions.publish"), name: nil, type: "button", class:  "action publish one-line"}
  end

  def create_draft
    { link_to: true, text: I18n.t("content.actions.revise"), path: create_draft_casebook_path(casebook), method: :post, type: "button", class: "action edit one-line create-draft" }
  end

  def edit_casebook
    { link_to: true, text: I18n.t("content.actions.revise-draft"), path: edit_casebook_path(casebook), method: :get, class: "action edit one-line" }
  end

  def edit_draft
    if has_published_parent
      { link_to: true, text: I18n.t("content.actions.revise-draft"), path: edit_casebook_path(casebook), class: "action edit one-line" }
    else
      { link_to: true, text: I18n.t("content.actions.revise-draft"), path: edit_casebook_path(draft), method: :get, class: "action edit one-line" }
    end
  end

  def clone_casebook
    { button_to: true, text: I18n.t("content.actions.clone"), path: clone_casebook_path(casebook), class: "action clone-casebook", method: :post, form: {class: "clone_casebook"} }
  end

  def preview_casebook
    { link_to: true, text: I18n.t("content.actions.preview"), path: casebook_path(casebook), class: "action one-line preview" }
  end

  def add_resource
    { link_to: true, text: I18n.t('content.actions.add-resource'), path: new_section_path(casebook), class: 'action add-resource' }
  end

  def add_section
    { button_to: true, text: I18n.t("content.actions.add-section"), path: sections_path(casebook, params: {parent: section.try(:id)}), method: :post, class: "action add-section" }
  end

  def save_casebook
    { button_to: true, text: I18n.t("content.actions.save"), path: "", class: "action one-line save submit-section-details" }
  end

  def cancel_casebook
    { link_to: true, text: I18n.t("content.actions.cancel"), path: "", class: "action one-line cancel cancel-casebook-details" }
  end

  #### 
  # Used for all 

  def export
    if casebook.resources_have_annotations?
      { link_to: true, path: "#", text: I18n.t("content.actions.export"), class: "action one-line export export-has-annotations" }
    else
      { link_to: true, path: "#", text: I18n.t("content.actions.export"), class: 'action one-line export export-no-annotations' }
    end
  end


  ######
  #Live draft logic

  def draft
    casebook.draft
  end

  def has_published_parent
    casebook.draft_mode_of_published_casebook
  end

  def draft_section
    casebook.draft.contents.where(copy_of_id: section.id).first
  end

  def draft_resource
    casebook.draft.contents.where(copy_of_id: resource.id).first
  end
end
