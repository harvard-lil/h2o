class Content::NodeDecorator < Draper::Decorator
  include Draper::LazyHelpers

  def action_buttons
    if self.is_a?(Content::Casebook)
      casebook_actions
    elsif self.is_a? Content::Section
      section_actions
    else
      resource_actions
    end
  end

  private

  def casebook_actions
    if published 
      if authorized
        if has_draft
          edit_draft + clone_and_export
        else
          create_draft + clone_and_export
        end
      end
      clone_and_export
    elsif preview
      if has_draft
        # cannot clone in draft mode because it will be nested underneath the draft and not surface to user
        publish_changes_to_casebook + edit_draft +export_casebook
      else
        publish_casebook + edit_casebook + clone_and_export
      end
    elsif draft
      if draft_of_published_casebook
        publish_changes_to_casebook + preview_casebook + draft_buttons
      else
        publish_casebook + preview_casebook + draft_buttons
      end
    end
  end

  def section_actions
    if published 
      if authorized
        if has_draft
          if draft_resource.present?
            revise_draft_section + clone_and_export
          else
            # fill in
          end
        else
          create_section_draft + clone_and_export
        end
        clone_and_export
      end
    elsif preview
      if has_draft
        publish_changes_to_casebook + edit_draft + export_casebook
      else
        publish_casebook + edit_casebook + clone_and_export
      end
    elsif draft
      # cannot published from section so do not need different buttons if it's a draft of a published casebook
      preview_section + draft_buttons
    end
  end

  def resource_actions
    if published 
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
    elsif preview
      if has_draft
        publish_changes_to_casebook + edit_draft + export_casebook
      else
        publish_casebook + edit_casebook + clone_and_export
      end
    elsif draft
      preview_resource + save_resource + cancel_resource + export_resource
    end
  end

  def authorized
    if current_user.present?
      casebook.has_collaborator?(current_user.id) || current_user.superadmin?
    else 
      false
    end
  end

  def published
    casebook.public
  end

  def draft_of_published_casebook
    casebook.draft_mode_of_published_casebook
  end

  def clone_and_export
    clone_casebook + export_casebook
  end

  def draft_buttons
    add_resource + add_section + export_casebook + save_casebook + cancel_casebook
  end


end
