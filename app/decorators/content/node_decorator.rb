# decorates casebooks, sections and resources with the appropriate actions buttons
class Content::NodeDecorator < Draper::Decorator
  include Draper::LazyHelpers
  attr_accessor :builder, :casebook, :section, :resource, :action

  def build_params
    @casebook = context[:casebook]
    @section = context[:section]
    @resource = context[:context_resource]
    @action = context[:action_name]
    @builder = ActionButtonBuilder.new(casebook, section, resource, action)
  end

  def action_buttons
    build_params

    if self.is_a?(Content::Casebook)
      buttons = casebook_actions
    elsif self.is_a? Content::Section
      buttons = section_actions
    else
      buttons = resource_actions
    end

    builder.perform(buttons)
  end

# private

  def casebook_actions
    if published_mode
      if authorized
        if has_draft
          # [:edit_draft] << clone_and_export
          # [:edit_draft] << clone_and_export
          [:clone_casebook]
        else
          # create_draft + clone_and_export
          [:clone_casebook]
        end
      end
      # clone_and_export
    elsif preview_mode
      if has_draft
        # cannot clone in draft mode because it will be nested underneath the draft and not surface to user
        publish_changes_to_casebook + edit_draft + export_casebook
      else
        publish_casebook + edit_casebook + clone_and_export
      end
    else draft_mode
      if published_casebook_draft
        publish_changes_to_casebook + preview_casebook + draft_buttons
      else
        publish_casebook + preview_casebook + draft_buttons
      end
    end
  end

  def section_actions
    if published_mode
      if authorized
        if has_draft
          if draft_resource.present? # does the draft version of the resource still exist
            revise_draft_section + clone_and_export
          else
            # fill in
          end
        else
          create_section_draft + clone_and_export
        end
        clone_and_export
      end
    elsif preview_mode
      if has_draft
        publish_changes_to_casebook + edit_draft + export_casebook
      else
        publish_casebook + edit_casebook + clone_and_export
      end
    elsif draft_mode
      # cannot published from section
      preview_section + draft_buttons
    end
  end

  def resource_actions
    if published_mode
      if authorized
        if has_draft
          if draft_resource.present?
            annotate_resource_draft + clone_and_export
          else
            ## insert 
          end
        else
          create_draft + clone_and_export
        end
        clone_and_export
      end
    elsif preview_mode
      if has_draft
        publish_changes_to_casebook + edit_draft + export_casebook
      else
        publish_casebook + edit_casebook + clone_and_export
      end
    elsif draft_mode
      [:preview_resource, :save_resource, :cancel_resource, :export_resource]
    end
  end

  #condensed button lists

  def clone_and_export
    [:clone_casebook, :export_casebook]
  end

  def draft_buttons
    add_resource + add_section + export_casebook + save_casebook + cancel_casebook
  end

  #variables

  def draft_mode
    action.in? %w{edit layout annotate}
  end

  def published_mode
    casebook.public
  end

  def preview_mode
    authorized && action == 'show'
  end

  def has_draft
    casebook.draft.present?
  end

  def published_casebook_draft
    casebook.draft_mode_of_published_casebook
  end

  def authorized
    if current_user.present?
      casebook.has_collaborator?(current_user.id) || current_user.superadmin?
    else 
      false
    end
  end

end
