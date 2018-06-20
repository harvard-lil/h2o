class BaseController < ApplicationController
  caches_page :index, :if => Proc.new { |c| c.instance_variable_get('@page_cache') }

  layout :layout_switch

  def landing
    if current_user
      @user = current_user
      @page_title = I18n.t 'content.titles.dashboard'
      render 'content/dashboard', layout: 'main'
    else
      render 'base/index', layout: 'main'
    end
  end

  def error
    redirect_to root_url, :status => 301
  end

  def not_found
    render :file => "#{Rails.root}/public/404.html", :status => 404, :layout => false
  end

  # Layout is always false for ajax calls
  def layout_switch
    return false if request.xhr?
  end
end
