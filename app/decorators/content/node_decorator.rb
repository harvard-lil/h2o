# decorates casebooks, sections and resources with the appropriate actions buttons
class Content::NodeDecorator < Draper::Decorator
  include Draper::LazyHelpers
  attr_accessor :builder, :casebook, :section, :resource, :action_name

  def action_buttons
    build_params

    if self.is_a?(Content::Casebook)
      actions = casebook_actions
    elsif self.is_a? Content::Section
      actions = section_actions
    else
      actions = resource_actions
    end

    # flatten actions incase it's an array of multiple arrays from clone_and_export, etc.
    builder.perform(actions.flatten)
  end

  private

  def build_params
    @casebook = context[:casebook]
    @section = context[:section]
    @resource = context[:context_resource]
    @action_name = context[:action_name]
    @builder = ActionButtonBuilder.new(casebook, section, resource, action_name)
  end

  def casebook_actions
    if casebook.public?
      if authorized?
        if casebook.draft.present?
          return [:edit_draft] << clone_and_export
        else
          return [:create_draft] << clone_and_export
        end
      elsif current_user.present?
        return clone_and_export
      elsif anonymous?
        return [:export]
      end
    elsif preview_mode
      if casebook.draft_mode_of_published_casebook?
        # cannot clone in draft mode because it will be nested underneath the draft and not surface to user.
        return [:publish_changes_to_casebook, :edit_draft, :export]
      else
        return [:publish_casebook, :edit_casebook] << clone_and_export
      end
    else draft_mode
      if casebook.draft_mode_of_published_casebook?
        return [:publish_changes_to_casebook, :preview_casebook] << draft_buttons
      else
        return [:publish_casebook, :preview_casebook] << draft_buttons
      end
    end
  end

  def section_actions
    if casebook.public?
      if authorized?
        if casebook.draft.present?
          # check if the corrosponding draft section still exists in the draft casebook
          if draft_section.present? 
            return [:revise_draft_section] << clone_and_export
          else
            return [:edit_draft] << clone_and_export
          end
        else
          return [:create_section_draft] << clone_and_export
        end
      elsif current_user.present?
        return clone_and_export
      elsif anonymous?
        return [:export]
      end
    elsif preview_mode
      if casebook.draft_mode_of_published_casebook?
        return [:publish_changes_to_casebook, :edit_draft, :export]
      else
        return [:publish_casebook, :edit_casebook] << clone_and_export
      end
    elsif draft_mode
      # cannot published from section
      return [:preview_section] << draft_buttons
    end
  end

  def resource_actions
    if casebook.public?
      if authorized?
        if casebook.draft.present?
          # check if the corrosponding draft section still exists in the draft casebook
          if draft_resource.present?
            return [:annotate_resource_draft] << clone_and_export
          else
            return [:edit_draft] << clone_and_export
          end
        else
          return [:create_resource_draft] << clone_and_export
        end
      elsif current_user.present?
        return clone_and_export
      elsif anonymous?
        return [:export]
      end
    elsif preview_mode
      if casebook.draft_mode_of_published_casebook?
        return [:publish_changes_to_casebook, :edit_draft, :export]
      else
        return [:publish_casebook, :edit_casebook] << clone_and_export
      end
    elsif draft_mode
      return [:preview_resource, :save_resource, :cancel_resource, :export]
    end
  end

  #condensed button lists

  def clone_and_export
    # right now only casebooks can be cloned, not individual resources or sections
    [:clone_casebook, :export]
  end

  def draft_buttons
    [:add_resource, :add_section, :export, :save_casebook, :cancel_casebook]
  end

  #variables

  def draft_resource
    casebook.draft.contents.where(copy_of_id: resource.id).first
  end

  def draft_section
    casebook.draft.contents.where(copy_of_id: section.id).first
  end

  def draft_mode
    action_name.in? %w{edit layout annotate}
  end

  def preview_mode
    authorized? && action_name == 'show'
  end

  def authorized?
    if current_user.present?
      casebook.has_collaborator?(current_user.id) || current_user.superadmin?
    else 
      false
    end
  end

  def anonymous?
    current_user.blank?
  end
end
