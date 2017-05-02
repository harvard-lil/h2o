require 'net/http'
require 'uri'

class Casebooks::BooksController < ApplicationController
  layout 'casebooks'
  before_action :find_book, except: [:new, :create]
  before_action :canonical_redirect, except: [:new, :create]
  before_action :page_title

  def new
    @book = current_user.books.owned.unmodified.first ||
      Casebook::Book.create(public: false, collaborators: [Casebook::Collaborator.new(user: current_user, role: 'owner')])
    logger.debug @book.errors.inspect
    redirect_to edit_book_path @book
  end

  def edit
    @casebook = @book
    render 'casebooks/edit'
  end

  def show
    @casebook = @book
    render 'casebooks/show'
  end

  def update
    @book.update book_params
    return redirect_to book_sections_path @book if @book.valid?
    render 'casebooks/books/edit'
  end

  private

  def book_params
    params.require(:casebook_book).permit(:title, :subtitle, :ordinals, :headnote)
  end

  def find_book
    @book = Casebook::Book.find params[:id]
  end

  def canonical_redirect
    unless params[:id] == @book.to_param
      return redirect_to url_for(params.permit(:controller, :action).merge id: @book.to_param)
    end
  end

  def page_title
    @page_title = if @book.present?
      if action_name == 'edit'
        I18n.t 'casebooks.titles.books.edit', book_title: @book.title
      else
        I18n.t 'casebooks.titles.books.show', book_title: @book.title
      end
    else
      I18n.t 'casebooks.titles.books.index'
    end
  end
end
