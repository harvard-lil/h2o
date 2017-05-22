require 'net/http'
require 'uri'

# Abstract controller for behavior shared between Casebook and Section/Resource views
class Content::NodeController < ApplicationController
  layout 'casebooks'
  before_action :find_casebook, if: lambda {params[:casebook_id].present?}
  before_action :find_section, if: lambda {params[:id_ordinals].present?}

  before_action :check_public, only: [:show, :index, :clone]
  before_action :check_authorized, except: [:show, :index, :new, :clone]

  before_action :set_page_title
  before_action :canonical_redirect, only: [:show, :index]

  private

  def check_public
    @content.public || check_authorized
  end

  def check_authorized
    if current_user.present?
      return if @content.owners.include? current_user
      flash[:notice] = I18n.t('content.errors.unauthorized')
      redirect_to user_path(current_user)
    else
      session[:return_to] ||= request.url
      flash[:notice] = I18n.t('content.errors.not-signed-in')
      redirect_to new_user_session_path
    end
  end

  def canonical_redirect
    if @section
      unless params[:casebook_id] == @casebook.to_param && params[:id_ordinals] == @section.to_param
        return redirect_to url_for(params.permit(:controller, :action).merge casebook_id: @casebook.to_param, id_ordinals: @section.to_param)
      end
    else
      unless params[:casebook_id] == @casebook.to_param
        return redirect_to url_for(params.permit(:controller, :action).merge casebook_id: @casebook.to_param)
      end
    end
  end

  def content_params
    (params[:content_casebook] || params[:content_section] || params[:content_resource]).permit(:title, :subtitle, :headnote, :public, ordinals: [])
  end

  def disable_turbolinks_cache
    @turbolinks_no_cache = true
  end

  def find_casebook
    @content = @casebook = Content::Casebook.find params[:casebook_id]
  end

  def find_section
    @content = @section = @casebook.contents.find_by_ordinals parse_ordinals(params[:id_ordinals].split('-')[0])
    unless @section.present?
      return redirect_to casebook_path(@casebook)
    end
  end

  def find_parent
    @parent = if params[:parent]
      @section = @casebook.contents.find_by_ordinals parse_ordinals(params[:parent])
    else
      @casebook
    end
  end

  def parse_ordinals ordinals
    ordinals = ordinals.split(/\.|,/) if ordinals.is_a? String
    ordinals.map &:to_i
  end

  def set_page_title
    @page_title = page_title
  end
end
