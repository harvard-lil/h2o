class UserSessionsController < ApplicationController
  before_filter :display_first_time_canvas_notice, :only => [:new]
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

    @user_session = UserSession.new(params[:user_session])
    @user_session.save do |result|
      if result
        apply_user_preferences(@user_session.user, false)
        if request.xhr?
          #Text doesn't matter, status code does.
          render :text => 'Success!', :layout => false
        else
          if first_time_canvas_login?
            save_canvas_id_to_user(@user_session.user)
            flash[:notice] = "You canvas id was attached to this account"
            redirect_to user_path(@user_session.user)
          else
            redirect_back_or_default "/"
          end
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
end
