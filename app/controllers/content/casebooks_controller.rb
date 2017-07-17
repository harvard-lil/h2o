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

  def clone
    @clone = current_user.casebooks.owned.where(copy_of: @casebook).first ||
      @casebook.clone(owner: current_user)
    redirect_to casebook_path(@clone)
  end

  def update
    @casebook.update content_params
    return redirect_to casebook_section_index_path @casebook if @casebook.valid?
    render 'content/casebooks/edit'
  end

  def export
    html = render_to_string layout: 'export'
    respond_to do |format|
      format.pdf {
        send_file Export::PDF.save(html, annotations: params[:annotations] != 'false'), type: 'application/pdf', filename: helpers.truncate(@casebook.title, length: 45, omission: '-', separator: ' ') + '.pdf', disposition: :inline
      }
      format.docx {
        send_file Export::DOCX.save(html, annotations: params[:annotations] != 'false'), type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: helpers.truncate(@casebook.title, length: 45, omission: '-', separator: ' ') + '.docx', disposition: :inline
      }
      format.html { render body: html, layout: false }
    end
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
