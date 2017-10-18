class Content::NodeDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def action_buttons
    if draft_mode?
      draft_action_buttons
    elsif published_mode?
      preview_action_buttons
    elsif 
      published_action_buttons
    end
    button_to I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook'
    link_to I18n.t('content.actions.export'), export_casebook_path(casebook), class: 'action one-line export'
  end

  private

  def draft_action_buttons
    if self.is_a? Content::Casebook
      casebook_draft
    elsif self.is_a? Content::Section
      section_draft
    else 
      resource_draft
    end
  end

  def casebook_draft
    ## only rendering last item
    button_to I18n.t('content.actions.publish'), casebook_path(casebook), method: :patch, params: {content_casebook: {public: true}}, class: 'action publish one-line'
    link_to I18n.t('content.actions.preview'), casebook_path(casebook), class: 'action one-line preview'
    link_to I18n.t('content.actions.add-resource'), new_section_path(casebook), class: 'action add-resource'
    button_to I18n.t('content.actions.add-section'), sections_path(casebook, params: {parent: @section.try(:id)}), method: :post, class: 'action add-section'
  end

  def section_draft
    link_to I18n.t('content.actions.preview'), section_path(casebook, section), class: 'action one-line preview'
    link_to I18n.t('content.actions.add-resource'), new_section_path(casebook), class: 'action add-resource'
    button_to I18n.t('content.actions.add-section'), sections_path(casebook, params: {parent: section.try(:id)}), method: :post, class: 'action add-section'
    link_to I18n.t('content.actions.save'), edit_section_path(casebook, section), class: 'action one-line save submit-section-details'
    link_to I18n.t('content.actions.cancel'), edit_section_path(casebook, section), class: 'action one-line cancel'
  end

  def resource_draft
    link_to I18n.t('content.actions.preview'), resource_path(casebook, resource), class: 'action one-line preview'
    if action_name == 'edit'
      link_to I18n.t('content.actions.save'), edit_resource_path(casebook, resource), class: 'action one-line save submit-edit-details'
      link_to I18n.t('content.actions.cancel'), edit_resource_path(casebook, resource), class: 'action one-line cancel'
    end
  end

  def preview_action_buttons
    if self.is_a? Content::Casebook
      casebook_preview
    elsif self.is_a? Content::Section
      section_preview
    else 
      resource_preview
    end
  end

  def casebook_preview
    button_to I18n.t('content.actions.publish'), casebook_path(casebook), method: :patch, params: {content_casebook: {public: true}}, class: 'action publish one-line'
    link_to I18n.t('content.actions.revise'), layout_casebook_path(casebook), class: 'action edit one-line'
  end

  def section_preview
    link_to I18n.t('content.actions.revise'), layout_section_path(casebook, section), class: 'action edit one-line'
  end

  def resource_preview
    link_to I18n.t('content.actions.revise'), annotate_resource_path(casebook, resource), class: 'action edit one-line'
  end

  def published_action_buttons
    if self.is_a? Content::Casebook
      casebook_published
    elsif self.is_a? Content::Section
      section_published
    else 
      resource_published
    end
  end

  def casebook_published
    link_to I8n.t('content.actions.revise'), edit_casebook_path(casebook), class: 'action edit one-line'
  end

  def section_published
    link_to I18n.t('content.actions.revise'), edit_section_path(casebook, section), class: 'action edit one-line'
  end

  def resource_published
    link_to I18n.t('content.actions.revise'), annotate_resource_path(casebook, resource), class: 'action edit one-line'
  end

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
    owned && casebook.public
  end

  def preview_mode?
    owned && action_name == 'show'
  end

  def owned
    self.owners.include(current_user)
  end

  # def action_button_content 
  #   if casebook and draft 
  # end

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

end
