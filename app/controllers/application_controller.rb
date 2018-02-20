class ApplicationController < ActionController::Base
  # Important that check_auth happens after load_single_resource
  before_action :set_time_zone, :redirect_bad_format
  before_action :prepare_exception_notifier

  after_action(if: Proc.new {Rails.env.development?}) {I18n.backend.reload!}
  after_action :allow_iframe

  protect_from_forgery with: :exception

  helper :all
  helper_method :current_user, :current_user_session

  def redirect_bad_format
    if params[:format] == "php"
      # Note: This has to be hardcoded, not root_url
      redirect_to "/", :status => 301
      true
    elsif params[:format] == "zip"
      # This exists to prevent garbage exceptions in the Rails log caused by
      # spam links pointing to this non-existent route, and returns a 404 specifically
      # to detract from spam links' Google juice
      raise ActionController::RoutingError.new('Not Found')
    end
  end

  #Switch to local time zone
  def set_time_zone
    if current_user && ! current_user.tz_name.blank?
      Time.zone = current_user.tz_name
    end
  end

  private
  # def common_user_preference_attrs
  #   [
  #     :user_id,
  #     :default_font_size, :default_font, :tab_open_new_items, :simple_display,
  #     :print_titles, :print_paragraph_numbers, :print_annotations,
  #     :print_highlights, :print_font_face, :print_font_size, :default_show_comments,
  #     :default_show_paragraph_numbers, :hidden_text_display, :print_links,
  #   ]
  # end


  def prepare_exception_notifier
    request.env["exception_notifier.exception_data"] = {
      :current_user => current_user
    }
  end

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.record
  end

  def redirect_back_or_default(default)
    redirect_to session[:return_to] || default
  end

  def iframe?
    false
  end

  def allow_iframe
    response.headers.except!('X-Frame-Options') if iframe?
  end

  rescue_from CanCan::AccessDenied do |exception|
    logger.debug "Access denied on #{exception.action} #{exception.subject.inspect} " +
      "for user: #{current_user.try(:id) || '(none)'}"

    if request.xhr?
      render :json => {
        :success => false,
        :message => "We could not perform this action. Please confirm that you are<br />logged in with cookies enabled.",
        :error => true,
      }
    else
      flash[:notice] = "You are not authorized to access this page."
      url = current_user.present? ? "/users/#{current_user.id}" : "/user_sessions/new"
      redirect_to url
    end
  end

  rescue_from ActionController::InvalidCrossOriginRequest do |exception|
  end
end
