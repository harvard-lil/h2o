class SettingsController < ApplicationController
  before_filter :load_user
  
  def index
    @page_title = "Settings | H2O Classroom Tools"
    update if request.put?
  end
  
  def update
    if @user.update_attributes(params[:user])
      apply_user_preferences!(@user)
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
