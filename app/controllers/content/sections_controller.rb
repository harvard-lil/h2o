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
    if @section.is_a? Content::Resource
      redirect_to annotate_resource_path @casebook, @section
    else
      redirect_to edit_section_path @casebook, @section
    end
  end

  def show
    render 'content/show'
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
    return redirect_to layout_section_path(@casebook, @section) if @section.valid?
  end

  def destroy
    if !@section.destroy
      flash[:error] = "Could not delete #{@section.ordinal_string} #{@section.title}"
    end
    redirect_to layout_casebook_path @casebook
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
