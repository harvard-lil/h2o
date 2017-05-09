require 'net/http'
require 'uri'

class Content::CasebooksController < Content::NodeController
  def new
    @casebook = current_user.casebooks.owned.unmodified.first ||
      Content::Casebook.create(public: false, collaborators: [Content::Collaborator.new(user: current_user, role: 'owner')])
    logger.debug @casebook.errors.inspect
    redirect_to edit_casebook_path @casebook
  end

  def edit
    @content = @casebook
    render 'content/edit'
  end

  def show
    @content = @casebook
    render 'content/show'
  end

  def update
    @casebook.update content_params
    return redirect_to casebook_section_index_path @casebook if @casebook.valid?
    render 'content/casebooks/edit'
  end

  private

  def page_title
    if @casebook.present?
      if action_name == 'edit'
        I18n.t 'content.titles.casebooks.edit', casebook_title: @casebook.title
      else
        I18n.t 'content.titles.casebooks.show', casebook_title: @casebook.title
      end
    else
      I18n.t 'content.titles.casebooks.index'
    end
  end
end
