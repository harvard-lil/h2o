class UserSessionsController < ApplicationController
  protect_from_forgery :except => [:create]
  layout 'main', only: [:new, :create]

  def index
    redirect_to root_url
  end

  def new
    redirect_to root_url and return if current_user.present?

    session[:return_to] = request.referrer

    @user_session = UserSession.new params.permit(:email_address)
    render :layout => !request.xhr?
  end

  def create
    redirect_to root_url and return if current_user.present?

    @user_session = UserSession.new(user_session_param)
    @user_session.save do |result|
      if result
        apply_user_preferences(@user_session.user, false)
        redirect_back_or_default "/"
      else
        render :action => :new
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
    params.fetch(:user_session, {}).permit(:email_address, :password, :remember_me)
  end
end
