require 'net/http'
require 'uri'

# Abstract controller for behavior shared between Casebook and Section/Resource views
class Content::NodeController < ApplicationController
  before_action :find_casebook, if: lambda {params[:casebook_id].present? || params[:casebook_casebook_id].present?}
  before_action :find_section, if: lambda {params[:section_ordinals].present?}
  before_action :find_resource, if: lambda {params[:resource_ordinals].present?}

  before_action :set_preview, only: [:show, :index, :details]
  before_action :set_editable, only: [:edit, :layout, :annotate]

  before_action :check_public, only: [:show, :index, :details, :clone, :export]
  before_action :check_authorized, except: [:show, :index, :details, :new, :clone, :export]

  before_action :set_page_title
  before_action :canonical_redirect, only: [:show, :index]

  layout 'casebooks'

  def details
    render 'content/details'
  end

  def layout
    # editing a casebook or section
    if @casebook.public
      return redirect_to casebook_path(@casebook)
    end
    @editable = true
    if @section.present?
      @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, context_resource: @resource, type: 'section'})
    else
      @decorated_content = @content.decorate(context: {action_name: action_name, casebook: @casebook, section: @section, context_resource: @resource, type: 'casebook'})
    end
    render 'content/layout'
  end

  private

  def check_public
    @content.public || check_authorized
  end

  def set_preview
    @preview = !@casebook.public
  end

  def check_authorized
    if current_user.present?
      return if @content.has_collaborator?(current_user.id) || (current_user && current_user.superadmin?)
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
      unless params[:casebook_id] == @casebook.to_param && params[:section_ordinals] == @section.to_param
        return redirect_to url_for(params.permit(:controller, :action).merge casebook_id: @casebook.to_param, section_ordinals: @section.to_param)
      end
    elsif @resource
      unless params[:casebook_id] == @casebook.to_param && params[:resource_ordinals] == @resource.to_param
        return redirect_to url_for(params.permit(:controller, :action).merge casebook_id: @casebook.to_param, resource_ordinals: @resource.to_param)
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

  def find_casebook
    @content = @casebook = Content::Casebook.includes(contents: [:resource]).find params[:casebook_id] || params[:casebook_casebook_id]
  end

  def find_section
    @content = @child = @section = @casebook.contents.find_by_ordinals parse_ordinals(params[:section_ordinals])
    unless @section.present?
      return redirect_to casebook_path(@casebook)
    end
  end

  def find_resource
    @content = @child = @resource = @casebook.contents.find_by_ordinals parse_ordinals(params[:resource_ordinals])
    unless @resource.present?
      return redirect_to casebook_path(@casebook)
    end
  end

  def find_parent
    @parent = if params[:parent].present?
      @section = @casebook.contents.find_by_id parse_ordinals(params[:parent])
    else
      @casebook
    end
  end

  def parse_ordinals ordinals
    ordinals = ordinals.split('-')[0].split(/\.|,/) if ordinals.is_a? String
    ordinals.map &:to_i
  end

  def set_page_title
    @page_title = page_title
  end

  def set_editable
    @editable = true
  end

  def prevent_page_caching
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma']        = 'no-cache'
    response.headers['Expires']       = '0'
  end
end
