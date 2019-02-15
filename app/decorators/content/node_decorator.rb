# decorates casebooks, sections and resources with the appropriate actions buttons
class Content::NodeDecorator < Draper::Decorator
  include Draper::LazyHelpers
  helper :action_buttons

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
    if published_mode
      if authorized
        if has_draft
          edit_draft + clone_and_export
        else
          create_draft + clone_and_export
        end
      end
      clone_and_export
    elsif preview_mode
      if has_draft
        # cannot clone in draft mode because it will be nested underneath the draft and not surface to user
        publish_changes_to_casebook + edit_draft + export_casebook
      else
        publish_casebook + edit_casebook + clone_and_export
      end
    else draft_mode
      if draft_of_published_casebook
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
      preview_resource + save_resource + cancel_resource + export_resource
    end
  end
end
