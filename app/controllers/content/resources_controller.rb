require 'net/http'
require 'uri'

class Content::ResourcesController < Content::NodeController
  before_action :prevent_page_caching, only: [:export]
  skip_before_action :set_page_title, only: [:export]
  skip_before_action :check_public, only: [:export]

  def show
    @include_vuejs = true
    @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, context_resource: @resource, type: 'resource'})
  end

  def annotate
    @include_vuejs = true
    @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, context_resource: @resource, type: 'resource'})
    render 'show'
  end

  def edit
    # editing resource details
    if @casebook.public
      return redirect_to details_casebook_path(@casebook)
    end
    @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, context_resource: @resource, type: 'resource' })
    render 'content/resource_details'
  end

  def create_draft
    @casebook = @casebook.clone(true)
    @resource = @casebook.resources.find_by(copy_of_id: @resource.id)
    @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, context_resource: @resource, type: 'resource'})
    redirect_to annotate_resource_path(@casebook, @decorated_content)
  end

  def clone
    @casebook = @casebook.clone(false, current_user)
    @resource = @casebook.resources.find_by(copy_of_id: @resource.id)
    @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, context_resource: @resource, type: 'resource'})
    redirect_to annotate_resource_path(@casebook, @decorated_content)
  end

  def export
    @resource = Content::Resource.find params[:resource_id]
    @include_annotations = (params["annotations"] == "true")

    html = render_to_string(layout: 'export', include_annotations: @include_annotations)
    file_path = Rails.root.join("tmp/export-#{Time.now.utc.iso8601}-#{SecureRandom.uuid}.docx")

    # remove image tags
    nodes = Nokogiri::HTML.fragment(html)
    nodes.css('img').each do | img |
        img.remove
    end
    html = nodes.to_s

    #Htmltoword doesn't let you switch xslt. So we need to manually do it.
    if @include_annotations
      Htmltoword.config.default_xslt_path = Rails.root.join 'lib/htmltoword/xslt/with-annotations'
    else
      Htmltoword.config.default_xslt_path = Rails.root.join 'lib/htmltoword/xslt/no-annotations'
    end

    Htmltoword::Document.create_and_save(html, file_path)
    send_file file_path, type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: export_filename('docx', @include_annotations), disposition: :inline
  end

  def update
    if @casebook.draft_mode_of_published_casebook?
      @resource.create_revisions(content_params)

      if resource_params[:resource_attributes].present?
        @resource.create_revisions(resource_params[:resource_attributes])
      end
    end

    @resource.update_attributes(title: resource_params[:title], subtitle: resource_params[:subtitle],
      headnote: resource_params[:headnote])

    if resource_params[:resource_attributes].blank?
      @resource.update content_params
    elsif resource_params[:resource_attributes][:content] && @resource.resource.is_a?(TextBlock)
      @resource.resource.update_attributes(content: resource_params[:resource_attributes][:content])
      flash[:success] = "Text updated."
    elsif resource_params[:resource_attributes][:url] && @resource.resource.is_a?(Link)
      @resource.resource.update_attributes(url: resource_params[:resource_attributes][:url])
      flash[:success] = "URL updated."
    end
    redirect_to edit_resource_path(@casebook, @resource)
  end

  private

  def resource_params
    params.require(:content_resource).permit(:title, :subtitle, :headnote, :resource_attributes => [:url, :content])
  end

  def export_filename format, annotations=false
    suffix = annotations ? '_annotated' : ''
    helpers.truncate(@resource.title, length: 45, omission: '-', separator: ' ') + suffix + '.' + format
  end

  def page_title
    if @resource.present?
      if action_name == 'edit'
        I18n.t 'content.titles.resources.edit', casebook_title: @casebook.title, section_title: @resource.title, ordinal_string: @resource.ordinal_string
      else
        I18n.t 'content.titles.resources.show', casebook_title: @casebook.title, section_title: @resource.title,  ordinal_string: @resource.ordinal_string
      end
    else
      I18n.t 'content.titles.resources.read', casebook_title: @casebook.title, section_title: @resource.title,  ordinal_string: @resource.ordinal_string
    end
  end
end
