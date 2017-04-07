class UserSessionsController < ApplicationController
  protect_from_forgery :except => [:create]

  def index
    redirect_to root_url
  end

  def new
    redirect_to root_url and return if current_user.present?

    @user_session = UserSession.new
    render :layout => !request.xhr?
  end

  def create
    redirect_to root_url and return if current_user.present?

    @user_session = UserSession.new(user_session_param)
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
        render :action => :new, :layout => !request.xhr?, :status => :unprocessable_entity
      end
    end
  end

  def destroy
    destroy_user_preferences
    if current_user_session.present?
      current_user_session.destroy
    end
    redirect_back_or_default "/"
  end

  private

  def user_session_param
    params.require(:user_session).permit(:login, :password, :remember_me)
  end
end
