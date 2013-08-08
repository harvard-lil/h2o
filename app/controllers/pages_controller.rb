class PagesController < ApplicationController
  caches_page :show

  def show
    @page_cache = true
    if FileTest.exists?("#{Rails.root}/app/views/pages/#{params[:id]}.html.erb")
      @page_title = params[:id].capitalize + " | H2O Classroom Tools" 
      render params[:id]
    else
      redirect_to "/", :status => 301
    end
  end
end
