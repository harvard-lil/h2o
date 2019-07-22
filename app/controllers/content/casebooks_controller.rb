require 'net/http'
require 'uri'

class Content::CasebooksController < Content::NodeController
  before_action :prevent_page_caching, only: [:export]
  before_action :set_editable, only: [:show, :index]
  before_action :require_user, only: [:clone]

  def new
    @casebook = Content::Casebook.create(public: false, collaborators: [Content::Collaborator.new(user: current_user, role: 'owner', has_attribution: true)])
    logger.debug @casebook.errors.inspect
    @content = @casebook
    redirect_to layout_casebook_path(@content)
  end

  def show
    @decorated_content = @casebook.decorate(context: {action_name: action_name, casebook: @casebook, type: 'casebooks'})
    render 'content/show' # preview page
  end

  def edit
    @casebook.update_attributes public: false
    @content = @casebook
    redirect_to layout_casebook_path(@content)
  end

  def create_draft
    @clone = @casebook.clone(true)
    redirect_to layout_casebook_path(@clone)
  end

  def clone
    @clone = @casebook.clone(false, current_user)
    redirect_to layout_casebook_path(@clone)
  end

  def reorder
    @child = @casebook.contents.find_by_ordinals parse_ordinals(params[:child_ordinals])
    @child.update_attributes ordinals: params[:child][:ordinals]
    redirect_to layout_casebook_path(@casebook)
  end

  def update
    @casebook.update content_params
    if publishing_casebook? && @casebook.draft_mode_of_published_casebook
      results = MergeDraftIntoPublishedCasebook.perform(@casebook, @casebook.parent)
      @casebook = results[:casebook]

      if results[:success] == false
        flash[:error] = 'Updating published casebook failed. Admin has been notified'
        @casebook.update(public: false)
      end

    elsif @casebook.draft_mode_of_published_casebook
      @casebook.create_revisions(content_params)
    end

    return redirect_to layout_casebook_path @casebook if @casebook.valid?
  end

  def export
    # does this need to be decorated?
    @decorated_content = @casebook.decorate(context: {action_name: action_name, casebook: @casebook, type: 'casebook'})
    @include_annotations = (params["annotations"] == "true")

    html = render_to_string(layout: 'export', include_annotations: @include_annotations)

    # remove image tags
    nodes = Nokogiri::HTML.fragment(html)
    nodes.css('img').each do | img |
        img.remove
    end
    html = nodes.to_s

    html.gsub! /\\/, '\\\\\\'
    file_path = Rails.root.join("tmp/export-#{Time.now.utc.iso8601}-#{SecureRandom.uuid}.docx")

    #Htmltoword doesn't let you switch xslt. So we need to manually do it.
    if @include_annotations
      Htmltoword.config.default_xslt_path = Rails.root.join 'lib/htmltoword/xslt/with-annotations'
    else
      Htmltoword.config.default_xslt_path = Rails.root.join 'lib/htmltoword/xslt/no-annotations'
    end

    Htmltoword::Document.create_and_save(html, file_path)
    send_file file_path, type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: export_filename('docx', @include_annotations), disposition: :inline
  end

  private

  def publishing_casebook?
    params[:content_casebook][:public]
  end

  def export_filename format, annotations=false
    suffix = annotations ? '_annotated' : ''
    helpers.truncate(@casebook.title, length: 45, omission: '-', separator: ' ') + suffix + '.' + format
  end

  def set_editable
    @edit_layout = !@preview && !@casebook.public && @casebook.collaborators.include?(current_user)
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
