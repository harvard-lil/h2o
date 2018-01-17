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

  def headnote
    if type == 'resource'
      resource_headnote
    elsif type == 'section'
      section_headnote
    elsif type == 'casebook'
      casebook_headnote
    end
  end

  private

  def casebook_headnote
    Nokogiri::HTML casebook.headnote {|config| config.strict.noblanks}
  end

  def section_headnote
    Nokogiri::HTML section.headnote {|config| config.strict.noblanks}
  end

  def resource_headnote
    Nokogiri::HTML resource.headnote {|config| config.strict.noblanks}
  end

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
    button_to(I18n.t('content.actions.publish'), casebook_path(casebook), method: :patch, params: {content_casebook: {public: true}}, class: 'action publish one-line') +
    link_to(I18n.t('content.actions.preview'), casebook_path(casebook), class: 'action one-line preview') +
    link_to(I18n.t('content.actions.add-resource'), new_section_path(casebook), class: 'action add-resource') +
    button_to(I18n.t('content.actions.add-section'), sections_path(casebook, params: {parent: @section.try(:id)}), method: :post, class: 'action add-section') +
    button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
    link_to(I18n.t('content.actions.export'), export_casebook_path(casebook), class: 'action one-line export') +
    link_to(I18n.t('content.actions.save'), edit_casebook_path(casebook), class: 'action one-line save submit-casebook-details') +
    link_to(I18n.t('content.actions.cancel'), edit_casebook_path(casebook), class: 'action one-line cancel')
  end

  def section_draft
    link_to(I18n.t('content.actions.preview'), section_path(casebook, section), class: 'action one-line preview') +
    link_to(I18n.t('content.actions.add-resource'), new_section_path(casebook), class: 'action add-resource') +
    button_to(I18n.t('content.actions.add-section'), sections_path(casebook, params: {parent: section.try(:id)}), method: :post, class: 'action add-section') +
    link_to(I18n.t('content.actions.save'), edit_section_path(casebook, section), class: 'action one-line save submit-section-details') +
    link_to(I18n.t('content.actions.cancel'), edit_section_path(casebook, section), class: 'action one-line cancel') +
    link_to(I18n.t('content.actions.export'), section_export_path(section), class: 'action one-line export')
  end

  def resource_draft
    if action_name == 'edit'
      link_to(I18n.t('content.actions.preview'), resource_path(casebook, resource), class: 'action one-line preview') +
      link_to(I18n.t('content.actions.save'), edit_resource_path(casebook, resource), class: 'action one-line save submit-edit-details') +
      link_to(I18n.t('content.actions.cancel'), edit_resource_path(casebook, resource), class: 'action one-line cancel') +
      link_to(I18n.t('content.actions.export'), resource_export_path(resource), class: 'action one-line export')
    else
      link_to(I18n.t('content.actions.preview'), resource_path(casebook, resource), class: 'action one-line preview') +
      link_to(I18n.t('content.actions.export'), resource_export_path(resource), class: 'action one-line export')
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
    button_to(I18n.t('content.actions.publish'), casebook_path(casebook), method: :patch, params: {content_casebook: {public: true}}, class: 'action publish one-line') +
    link_to(I18n.t('content.actions.revise'), layout_casebook_path(casebook), class: 'action edit one-line') +
    button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
    link_to(I18n.t('content.actions.export'), export_casebook_path(casebook), class: 'action one-line export') 
  end

  def section_preview
    link_to(I18n.t('content.actions.revise'), layout_section_path(casebook, section), class: 'action edit one-line') +
    button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
    link_to(I18n.t('content.actions.export'), section_export_path(section), class: 'action one-line export') 
  end

  def resource_preview
    link_to(I18n.t('content.actions.revise'), annotate_resource_path(casebook, resource), class: 'action edit one-line') +
    button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
    link_to(I18n.t('content.actions.export'), resource_export_path(resource), class: 'action one-line export') 
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
    if owner?
      link_to(I18n.t('content.actions.revise'), edit_casebook_path(casebook), class: 'action edit one-line') +
      button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
      link_to(I18n.t('content.actions.export'), export_casebook_path(casebook), class: 'action one-line export')
    else
      button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
      link_to(I18n.t('content.actions.export'), export_casebook_path(casebook), class: 'action one-line export') 
    end
  end

  def section_published
    if owner?
      link_to(I18n.t('content.actions.revise'), edit_section_path(casebook, section), class: 'action edit one-line') +
      button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
      link_to(I18n.t('content.actions.export'), section_export_path(section), class: 'action one-line export') 
    else
      button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
      link_to(I18n.t('content.actions.export'), section_export_path(section), class: 'action one-line export') 
    end
  end

  def resource_published
    if owner?
      link_to(I18n.t('content.actions.revise'), annotate_resource_path(casebook, resource), class: 'action edit one-line') +
      button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
      link_to(I18n.t('content.actions.export'), resource_export_path(resource), class: 'action one-line export') 
    else
      button_to(I18n.t('content.actions.clone-casebook'), clone_casebook_path(casebook), method: :post, class: 'action clone-casebook') +
      link_to(I18n.t('content.actions.export'), resource_export_path(resource), class: 'action one-line export') 
    end
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

  def type
    context[:type]
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
