require 'net/http'
require 'uri'

class Content::CasebooksController < Content::NodeController
  before_action :set_editable, only: [:show, :index]
  before_action :require_user, only: [:clone]

  def new
    @casebook = current_user.casebooks.owned.unmodified.first ||
      Content::Casebook.create(public: false, collaborators: [Content::Collaborator.new(user: current_user, role: 'owner')])
    logger.debug @casebook.errors.inspect
    redirect_to edit_casebook_path @casebook
  end

  def show
    @content = @casebook
    render 'content/show'
  end

  def edit
    @casebook.update_attributes public: false
    @content = @casebook
    redirect_to layout_casebook_path(@content)
  end

  def clone
    @clone = current_user.casebooks.owned.where(copy_of: @casebook).first ||
      @casebook.clone(owner: current_user)
    redirect_to layout_casebook_path(@clone)
  end

  def reorder
    @child = @casebook.contents.find_by_ordinals parse_ordinals(params[:child_ordinals])
    @child.update_attributes ordinals: params[:child][:ordinals]
    redirect_to layout_casebook_path(@casebook)
  end

  def update
    @casebook.update content_params
    return redirect_to layout_casebook_path @casebook if @casebook.valid?
  end

  def export
    html = render_to_string layout: 'export'
    html.gsub! /\\/, '\\\\\\'
    respond_to do |format|
      format.pdf {
        send_file Export::PDF.save(html, annotations: params[:annotations] != 'false'), type: 'application/pdf', filename: export_filename('pdf'), disposition: :inline
      }
      format.docx {
        file_path = Rails.root.join("tmp/export-#{Time.now.utc.iso8601}-#{SecureRandom.uuid}.docx")
        Htmltoword::Document.create_and_save(html, file_path)
        send_file file_path, type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: export_filename('docx'), disposition: :inline
        # render docx: 'export', filename: export_filename('docx')
        # send_file Export::DOCX.save(html, annotations: params[:annotations] != 'false'), type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: helpers.truncate(@casebook.title, length: 45, omission: '-', separator: ' ') + '.docx', disposition: :inline
      }
      format.html { render body: html, layout: false }
    end
  end

  private

  def export_filename format
    helpers.truncate(@casebook.title, length: 45, omission: '-', separator: ' ') + '.' + format
  end

  def set_editable
    @edit_layout = !@preview && !@casebook.public && @casebook.owners.include?(current_user)
  end

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

  def require_user
    if current_user.nil?
      session[:return_to] = request.referer
      redirect_to new_user_path
    end
  end
end