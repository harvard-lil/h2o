class UserSessionsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
  protect_from_forgery :except => [:create]
  
  def new
    @user_session = UserSession.new
    render :layout => (request.xhr?) ? false : true
  end
  
  def create
    @user_session = UserSession.new(params[:user_session])
    @user_session.save do |result|
      if result
        apply_user_preferences(@user_session.user, false)
        if request.xhr?
          #Text doesn't matter, status code does.
          render :text => 'Success!', :layout => false
        else
          redirect_back_or_default "/"
        end
      else
        render :action => :new, :layout => (request.xhr?) ? false : true, :status => :unprocessable_entity
      end
    end
  end
  
  def destroy
    destroy_user_preferences(current_user)
    current_user_session.destroy
    redirect_back_or_default "/"
  end
end
