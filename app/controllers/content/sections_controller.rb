require 'net/http'
require 'uri'

class Content::SectionsController < Content::NodeController
  before_action :find_parent, only: [:new, :create]
  skip_before_action :set_page_title, only: [:export]
  skip_before_action :check_public, only: [:export]

  def new
    @content = @parent
    if !params[:kind].in? %w{link text}
      @results = if params[:q]
        Sunspot.search(Case) do
          keywords params[:q]
        end
        .results
      else
        []
      end
    end
    render 'content/sections/new'
  end

  def create
    child_ordinals = @parent.ordinals + [@parent.children.length + 1]
    if params[:resource_id]
      resource = Case.find params[:resource_id]
      @section = Content::Resource.create! ordinals: child_ordinals, casebook:@casebook, resource: resource
    elsif params[:text]
      text = TextBlock.create(name: params[:text][:title], content: params[:text][:content])
      @section = Content::Resource.create! ordinals: child_ordinals, casebook:@casebook, resource: text
    elsif params[:link]
      url = UrlDomainFormatter.format(params[:link][:url])
      link = Default.create(url: url)
      @section = Content::Resource.create! ordinals: child_ordinals, casebook:@casebook, resource: link
    else
      @section = Content::Section.create! ordinals: child_ordinals, casebook:@casebook
    end

    if @section.is_a?(Content::Resource)
      if @section.resource_type == 'Default'
        redirect_to edit_resource_path @casebook, @section
      else
        redirect_to annotate_resource_path @casebook, @section
      end
    else
      @casebook.update_attributes public: false
      @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, context_resource: @resource, type: 'section'})
      redirect_to layout_section_path @casebook, @section
    end
  end

  def edit
    # editing a section takes you to a cloned casebook and
    # the original casebook stays published
    @casebook = @casebook.clone(owner: current_user, draft_mode: true)
    @section = @casebook.contents.find_by(copy_of_id: @section.id)
    @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, type: 'section'})
    redirect_to layout_section_path(@casebook, @section) 
  end

  def revise
    # revise without creating a draft
    redirect_to layout_section_path(@casebook, @section) 
  end

  def show
    @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, type: 'section'})
    render 'content/show'
  end

  def update
    if @casebook.draft_mode_of_published_casebook?
      @section.create_revisions(content_params)
    end

    @section.update content_params
    return redirect_to layout_section_path(@casebook, @section) if @section.valid?
  end

  def destroy
    @section.try(:contents).try(:destroy_all)

    if !@section.destroy
      flash[:error] = "Could not delete #{@section.ordinal_string} #{@section.title}"
    end

    present = @section.reflow_casebook.present?

    until present?
     render status: 200, plain: "section-deleted"
    end

   
    # @section.reflow_casebook
    # redirect_to layout_casebook_path @casebook, status: 301
  end

  def clone
    @casebook = @casebook.clone(owner: current_user)
    @section = @casebook.contents.find_by(copy_of_id: @section.id)
    @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, type: 'section'})
    redirect_to layout_section_path(@casebook, @section) 
  end

  def export
    @section = Content::Section.find params[:section_id]
    @decorated_content = @section.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, context_resource: @resource, type: 'section'})

    html = render_to_string layout: 'export'
    respond_to do |format|
      format.pdf {
        send_file Export::PDF.save(html, annotations: params[:annotations] != 'false'), type: 'application/pdf', filename: helpers.truncate(@section.title, length: 45, omission: '-', separator: ' ') + '.pdf', disposition: :inline
      }
      format.docx {
        file_path = Rails.root.join("tmp/export-#{Time.now.utc.iso8601}-#{SecureRandom.uuid}.docx")
        Htmltoword::Document.create_and_save(html, file_path)
        send_file file_path, type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: export_filename('docx'), disposition: :inline
        # send_file Export::DOCX.save(html, annotations: params[:annotations] != 'false'), type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: helpers.truncate(@resource.title, length: 45, omission: '-', separator: ' ') + '.docx', disposition: :inline
      }
      format.html { render body: html, layout: false }
    end
  end

  private

  def export_filename format
    helpers.truncate(@section.title, length: 45, omission: '-', separator: ' ') + '.' + format
  end

  def page_title
    if @section.present?
      if action_name == 'edit'
        I18n.t 'content.titles.sections.edit', casebook_title: @casebook.title, section_title: @section.title, ordinal_string: @section.ordinal_string
      else
        I18n.t 'content.titles.sections.show', casebook_title: @casebook.title, section_title: @section.title,  ordinal_string: @section.ordinal_string
      end
    else
      if action_name == 'new'
        I18n.t 'content.titles.casebooks.new', casebook_title: @casebook.title
      end
    end
  end
end
