class Content::NodeDecorator < Draper::Decorator
  include Draper::LazyHelpers

  def action_buttons
    if draft_mode?
      draft_action_buttons
    elsif published_mode?
      published_action_buttons
    else
      preview_action_buttons
    end
  end

  private

  def draft_action_buttons
    if self.is_a?(Content::Casebook) && casebook.draft_mode_of_published_casebook
      casebook_draft_of_published_casebook
    elsif self.is_a? Content::Casebook
      casebook_draft
    elsif self.is_a? Content::Section
      section_draft
    else
      resource_draft
    end
  end

  def published_action_buttons
    if self.is_a?(Content::Casebook) && has_live_draft?
      casebook_published_with_draft
    elsif self.is_a? Content::Casebook
      casebook_published
    elsif self.is_a?(Content::Section) && has_live_draft?
      section_published_with_draft
    elsif self.is_a? Content::Section
      section_published
    elsif has_live_draft?
      resource_published_with_draft
    else
      resource_published
    end
  end

  def preview_action_buttons
    if self.is_a?(Content::Casebook) && casebook.draft_mode_of_published_casebook
      casebook_preview_of_published_casebook
    elsif self.is_a? Content::Casebook
      casebook_preview
    elsif self.is_a? Content::Section
      section_preview
    else
      resource_preview
    end
  end

  #####################
  # Draft buttons

  def casebook_draft_of_published_casebook
    publish_changes_to_casebook +
    preview_casebook +
    add_resource +
    add_section +
    export_casebook +
    save_casebook +
    cancel_casebook
  end

  def casebook_draft
    publish_casebook +
    preview_casebook +
    add_resource +
    add_section +
    export_casebook +
    save_casebook +
    cancel_casebook +
    clone_casebook 
  end

  def section_draft
    preview_section +
    add_resource +
    add_section +
    save_section +
    cancel_section +
    export_section
  end

  def resource_draft
    if action_name == 'edit'
      preview_resource +
      save_resource +
      cancel_resource +
      export_resource
    else
      preview_resource +
      export_resource
    end
  end

  ###########
  # Published buttons

  def casebook_published_with_draft
    if owner?
      revise_draft +
      clone_casebook +
      export_casebook
    else
      clone_casebook +
      export_casebook
    end
  end

  def casebook_published
    if owner?
      revise_casebook +
      clone_casebook +
      export_casebook
    else
      clone_casebook +
      export_casebook
    end
  end

  def section_published_with_draft
    if owner?
      revise_draft_section +
      clone_casebook +
      export_section
    else
      clone_casebook +
      export_section
    end
  end

  def section_published
    if owner?
      revise_section +
      clone_casebook +
      export_section
    else
      clone_casebook +
      export_section
    end
  end

  def resource_published_with_draft
    if owner?
      annotate_resource_draft +
      clone_casebook +
      export_resource
    else
      clone_casebook +
      export_resource
    end
  end

  def resource_published
    if owner?
      annotate_resource +
      clone_casebook +
      export_resource
    else
      clone_casebook +
      export_resource
    end
  end

  ##########
  #Preview buttons

  def casebook_preview_of_published_casebook
    publish_changes_to_casebook +
    revise_casebook +
    export_casebook
  end

  def casebook_preview
    publish_casebook +
    revise_casebook +
    clone_casebook +
    export_casebook
  end

  def section_preview
    revise_section +
    clone_casebook +
    export_section
  end

  def resource_preview
    annotate_resource +
    clone_casebook +
    export_resource
  end

  ######
  #Live draft logic

  def has_live_draft?
    casebook.descendants.any? && casebook.descendants.where(draft_mode_of_published_casebook: true).present?
  end

  def draft
    casebook.descendants.joins(:collaborators).where(draft_mode_of_published_casebook: true).where('content_collaborators.user_id' => 124465).first
  end

  def draft_section
    draft.contents.where(copy_of_id: section.id).first
  end

  def draft_resource
    draft.contents.where(copy_of_id: resource.id).first
  end

  ####
  #Buttons/Links
  #Resources

  def annotate_resource_draft
    link_to(I18n.t('content.actions.revise'), annotate_resource_path(draft, draft_resource), class: 'action edit one-line')
  end

  def annotate_resource
    link_to(I18n.t('content.actions.revise'), clone_resource_path(casebook, resource), class: 'action edit one-line create-draft')
  end

  def export_resource
    link_to(I18n.t('content.actions.export'), resource_export_path(resource), class: 'action one-line export')
  end

  def preview_resource
    link_to(I18n.t('content.actions.preview'), resource_path(casebook, resource), class: 'action one-line preview')
  end

  def save_resource
    link_to(I18n.t('content.actions.save'), edit_resource_path(casebook, resource), class: 'action one-line save submit-edit-details')
  end

  def cancel_resource
    link_to(I18n.t('content.actions.cancel'), edit_resource_path(casebook, resource), class: 'action one-line cancel')
  end

  #############
  ## Section

  def revise_section
    link_to(I18n.t('content.actions.revise'), edit_section_path(casebook, section), class: 'action edit one-line')
  end

  def revise_draft_section
    link_to(I18n.t('content.actions.revise-draft'), edit_section_path(draft, draft_section), class: 'action edit one-line')
  end

  def export_section
    link_to(I18n.t('content.actions.export'), section_export_path(section), class: 'action one-line export')
  end

  def preview_section
    link_to(I18n.t('content.actions.preview'), section_path(casebook, section), class: 'action one-line preview')
  end

  def save_section
    link_to(I18n.t('content.actions.save'), edit_section_path(casebook, section), class: 'action one-line save submit-section-details')
  end

  def cancel_section
    link_to(I18n.t('content.actions.cancel'), edit_section_path(casebook, section), class: 'action one-line cancel')
  end

  ############
  ## Casebook

  def publish_changes_to_casebook
    button_to(I18n.t('content.actions.publish-changes'), casebook_path(casebook), method: :patch, params: {content_casebook: {public: true}}, class: 'action publish one-line')
  end

  def publish_casebook
    button_to(I18n.t('content.actions.publish'), casebook_path(casebook), method: :patch, params: {content_casebook: {public: true}}, class: 'action publish one-line')
  end

  def revise_casebook
    link_to(I18n.t('content.actions.revise'), edit_casebook_path(casebook), class: 'action edit one-line create-draft')
  end

  def revise_draft
    link_to(I18n.t('content.actions.revise-draft'), layout_casebook_path(draft), class: 'action edit one-line')
  end

  def clone_casebook
    button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook')
  end

  def export_casebook
    link_to(I18n.t('content.actions.export'), export_casebook_path(casebook), class: 'action one-line export')
  end

  def preview_casebook
    link_to(I18n.t('content.actions.preview'), casebook_path(casebook), class: 'action one-line preview')
  end

  def add_resource
    link_to(I18n.t('content.actions.add-resource'), new_section_path(casebook), class: 'action add-resource')
  end

  def add_section
    button_to(I18n.t('content.actions.add-section'), sections_path(casebook, params: {parent: @section.try(:id)}), method: :post, class: 'action add-section')
  end

  def save_casebook
    link_to(I18n.t('content.actions.save'), edit_casebook_path(casebook), class: 'action one-line save submit-casebook-details')
  end

  def cancel_casebook
    link_to(I18n.t('content.actions.cancel'), edit_casebook_path(casebook), class: 'action one-line cancel')
  end

  ############
  # Variables

  def casebook
    context[:casebook]
  end

  def section
    context[:section]
  end

  def resource
    context[:context_resource]
  end

  def action_name
    context[:action_name]
  end

  def draft_mode?
    action_name.in? %w{edit layout annotate}
  end

  def published_mode?
    casebook.public
  end

  def preview_mode?
    owner? && action_name == 'show'
  end

  def owner?
    casebook.owners.include?(current_user)
  end
end
