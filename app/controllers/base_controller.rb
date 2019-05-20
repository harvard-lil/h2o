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

  # Layout is always false for ajax calls
  def layout_switch
    return false if request.xhr?
  end
end
