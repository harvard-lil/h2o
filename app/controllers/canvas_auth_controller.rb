class CanvasAuthController < ApplicationController

  def authorize
    if requesting_app_is_authenticated?
      @user = find_canvas_user
      if @user
        login_user
		flash[:notice] = "You were logged in automatically from Canvas"
		redirect_to user_path(@user.id)
      else
        set_session_with_canvas_user_id
        redirect_to_h2o_login
      end
    else
      render 'unauthorized'
    end
  end

  def login_user
    UserSession.create(@user)
  end

  def requesting_app_is_authenticated?
    #canvas_auth = CanvasAuth.new(request)
    #canvas_auth.valid?
    true
  end

  def find_canvas_user
    User.find_by_canvas_id(params[:user_id])
  end

  def set_session_with_canvas_user_id
    session[:canvas_user_id] = params.fetch(:user_id)
  end

  def redirect_to_h2o_login
    redirect_to new_user_session_path
  end

  def lti_config
    render
  end
end
