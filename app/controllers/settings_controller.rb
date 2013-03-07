class SettingsController < ApplicationController
  before_filter :load_user
  before_filter :require_user
  def index
    @page_title = "Settings | H2O Classroom Tools"
    update if request.put?
  end
  
  def update   
    @user.default_font_size = params[:user][:default_font_size]
    @user.default_show_annotations = params[:user][:default_show_annotations]
    @user.tab_open_new_items = params[:user][:tab_open_new_items]
    if @user.save
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
