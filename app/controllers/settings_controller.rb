class SettingsController < ApplicationController
  before_filter :load_user
  
  def index
    update if request.put?
  end
  
  def update
    if @user.update_attributes(params[:user])
      @user.apply_preferences
      flash[:notice] = "Settings updated!"
      redirect_to settings_path
    else
      render :action => :index
    end
  end
  
  def load_user
    @user = current_user
  end
end
