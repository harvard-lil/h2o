class PagesController < ApplicationController
  def show
    if FileTest.exists?("#{Rails.root}/app/views/pages/#{params[:id]}.html.erb")
      render params[:id]
    else
      redirect_to "/", :status => 301
    end
  end
end
