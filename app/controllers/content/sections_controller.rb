require 'net/http'
require 'uri'

class Content::SectionsController < Content::NodeController
  before_action :find_parent, only: [:new, :create]
  before_action :disable_turbolinks_cache, only: [:new]

  def create
    child_ordinals = @parent.ordinals + [@parent.children.length + 1]
    if params[:resource_id]
      resource = Case.find params[:resource_id]
      @section = Content::Resource.create! ordinals: child_ordinals, casebook:@casebook, resource: resource
    elsif params[:text]
      text = TextBlock.create(name: params[:text][:title], content: params[:text][:content])
      @section = Content::Resource.create! ordinals: child_ordinals, casebook:@casebook, resource: text
    elsif params[:link]
      link = Default.create(url: params[:link][:url])
      @section = Content::Resource.create! ordinals: child_ordinals, casebook:@casebook, resource: link
    else
      @section = Content::Section.create! ordinals: child_ordinals, casebook:@casebook
    end
    redirect_to edit_section_path @casebook, @section
  end

  def show
    render 'content/layout'
  end

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

  def update
    @section.update content_params
    if params[:text_content] && @section.is_a?(Content::Resource) && @section.resource.is_a?(TextBlock)
      @section.resource.update_attribute :content, params[:text_content]
    end
    if params[:link_url] && @section.is_a?(Content::Resource) && @section.resource.is_a?(Default)
      @section.resource.update_attribute :url, params[:link_url]
    end
    if params[:reorder]
      redirect_back fallback_location: sections_path(@casebook)
    else
      return redirect_to section_path(@casebook, @section) if @section.valid?
      render 'content/content/edit'
    end
  end

  def destroy
    if !@section.destroy
      flash[:error] = "Could not delete #{@section.ordinal_string} #{@section.title}"
    end
    redirect_to sections_path @casebook
  end

  private

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
