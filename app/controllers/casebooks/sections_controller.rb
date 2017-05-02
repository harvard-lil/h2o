require 'net/http'
require 'uri'

class Casebooks::SectionsController < ApplicationController
  layout 'casebooks'
  before_action :find_book
  before_action :find_section, except: [:new, :create, :index]
  before_action :find_parent, only: [:new, :create]
  before_action :canonical_redirect, only: [:show]
  before_action :disable_turbolinks_cache, only: [:new]
  before_action :page_title

  def show
    @casebook = @section
    @edit_layout = @book.owners.include? current_user
    render 'casebooks/show'
  end

  def create
    child_ordinals = @parent.ordinals + [@parent.contents.length + 1]
    if params[:material_id]
      material = Case.find params[:material_id]
      @section = Casebook::Resource.create! ordinals: child_ordinals, root: @book, material: material
    else
      @section = Casebook::Section.create! ordinals: child_ordinals, root: @book
    end
    redirect_to edit_book_section_path @book, @section
  end

  def edit
    @casebook = @section
    render 'casebooks/edit'
  end

  def index
    @casebook = @book
    @edit_layout = @book.owners.include? current_user
    render 'casebooks/show'
  end

  def new
    @casebook = @parent
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
    render 'casebooks/sections/new'
  end

  def update
    @section.update section_params
    if params[:reorder]
      redirect_back fallback_location: book_sections_path(@book), status: 303
    else
      return redirect_to book_section_path(@book, @section) if @section.valid?
      render 'casebooks/books/edit'
    end
  end

  def destroy
    if !@section.destroy
      flash[:error] = "Could not delete #{@section.ordinal_string} #{@section.title}"
    end
    redirect_to book_sections_path @book
  end

  private

  def canonical_redirect
    unless params[:book_id] == @book.to_param && params[:id] == @section.to_param
      return redirect_to url_for(params.permit(:controller, :action).merge book_id: @book.to_param, id: @section.to_param)
    end
  end

  def section_params
    (params[:casebook_section] || params[:casebook_material]).permit(:title, :subtitle, :headnote, ordinals: [])
  end

  def disable_turbolinks_cache
    @turbolinks_no_cache = true
  end

  def find_book
    @book = Casebook::Book.find params.permit(:book_id)[:book_id]
  end

  def find_section
    @section = @book.contents.find_by_ordinals parse_ordinals(params[:id].split('-')[0])
  end

  def find_parent
    @parent = if params[:parent]
      @section = @book.contents.find_by_ordinals parse_ordinals(params[:parent])
    else
      @book
    end
  end

  def parse_ordinals ordinals
    ordinals = ordinals.split(/\.|,/) if ordinals.is_a? String
    ordinals.map &:to_i
  end

  def page_title
    @page_title = if @section.present?
      if action_name == 'edit'
        I18n.t 'casebooks.titles.sections.edit', book_title: @book.title, section_title: @section.title, ordinal_string: @section.ordinal_string
      else
        I18n.t 'casebooks.titles.sections.show', book_title: @book.title, section_title: @section.title,  ordinal_string: @section.ordinal_string
      end
    else
      I18n.t 'casebooks.titles.sections.index', book_title: @book.title
    end
  end
end
