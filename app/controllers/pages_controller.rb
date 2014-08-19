class PagesController < ApplicationController
  caches_page :show

  def show
    @page_cache = true
    @page = Page.where(slug: params[:id]).first
    if @page.nil?
      redirect_to root_url, :status => 301
    end
    @page_title = "#{@page.page_title} | H2O Classroom Tools"
  end
end
