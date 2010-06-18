# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  rescue_from Acl9::AccessDenied, :with => :deny_access

  helper :all
  helper_method :current_user_session, :current_user
  filter_parameter_logging :password, :password_confirmation

  layout :layout_switch

  before_filter :title_select, :set_time_zone

  #Switch to local time zone
  def set_time_zone
    if current_user && ! current_user.tz_name.blank?
      Time.zone = current_user.tz_name
    else
      Time.zone = DEFAULT_TIMEZONE 
    end
  end

  # Switches to nil layout for ajax calls.
  def layout_switch
    (request.xhr?) ? nil : :application
  end

  def title_select
    @logo_title = "default"
    case self.controller_name
      when "base" then @logo_title = "Home"
      when "rotisserie_instances", "rotisserie_discussions" then @logo_title = "Rotisserie"
      when "questions", "question_instances" then @logo_title = "Question Tool"
    else
      @logo_title = self.controller_name
    end

    @logo_title.upcase!
  end

  # Method executed when Acl9::AccessDenied is caught
  # should redirect to page with appropriate info
  # and possibly raise a 403?
  #--
  # FIXME: Place in redirect to error page
  #++
  def deny_access
    flash[:notice] = "You do not have access to this content."
    #redirect_to playlists_path
    
    redirect_back_or_default "/base"
  end

  def create_influence(original_object, spawned_object)
    original_influence = Influence.find_or_create_by_resource_id_and_resource_type(
      original_object.id, original_object.class.to_s)

    influence_record = Influence.new(:parent_id => original_influence.id)
    influence_record.resource = spawned_object
    influence_record.save!
  end

  protected

  # Accepts a string or an array and emits stylesheet tags in the layout in that order.
  def add_stylesheets(new_stylesheets)
    @stylesheets = [] if ! defined?(@stylesheets)
    @stylesheets << new_stylesheets
  end
  
  # Accepts a string or an array and emits javascript tags in the layout in that order.
  def add_javascripts(new_javascripts)
    @javascripts = [] if ! defined?(@javascripts)
    @javascripts << new_javascripts
  end

  private

    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.record
    end

    def require_user
      
      unless current_user
        store_location
        flash[:notice] = "You must be logged in to access this page"
        redirect_to crossroad_user_session_url
        #redirect_to new_user_session_url
        return false
      end
    end

    def require_no_user
      

      if current_user
        store_location
        flash[:notice] = "You must be logged out to access this page"
        redirect_to account_url
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

    def update_question_instance_time
      if ! @UPDATE_QUESTION_INSTANCE_TIME.blank?
        @UPDATE_QUESTION_INSTANCE_TIME.updated_at = Time.now
        @UPDATE_QUESTION_INSTANCE_TIME.save
      end
    rescue Exception => e
      logger.warn("Couldn't update question instance id: #{@UPDATE_QUESTION_INSTANCE_TIME.id} because #{e.inspect}")
    end




end
