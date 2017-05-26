require 'net/http'
require 'uri'

class Content::SectionsController < Content::NodeController
  before_action :find_parent, only: [:new, :create]
  before_action :disable_turbolinks_cache, only: [:new]

  def show
    @edit_layout = @casebook.owners.include? current_user
    render 'content/show'
  end

  def create
    child_ordinals = @parent.ordinals + [@parent.contents.length + 1]
    if params[:resource_id]
      resource = Case.find params[:resource_id]
      @section = Content::Resource.create! ordinals: child_ordinals, casebook:@casebook, resource: resource
    else
      @section = Content::Section.create! ordinals: child_ordinals, casebook:@casebook
    end
    redirect_to edit_casebook_section_path @casebook, @section
  end

  def edit
    render 'content/edit'
  end

  def index
    @edit_layout = @casebook.owners.include? current_user
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
    if params[:reorder]
      redirect_back fallback_location: casebook_section_index_path(@casebook)
    else
      return redirect_to casebook_section_path(@casebook, @section) if @section.valid?
      render 'content/content/edit'
    end
  end

  def destroy
    if !@section.destroy
      flash[:error] = "Could not delete #{@section.ordinal_string} #{@section.title}"
    end
    redirect_to casebook_section_index_path @casebook
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
