class ApplicationController < ActionController::Base
  # Important that check_auth happens after load_single_resource
  before_action :set_time_zone, :check_format
  before_action :prepare_exception_notifier
  before_action :check_superadmin

  after_action(if: Proc.new {Rails.env.development?}) {I18n.backend.reload!}

  protect_from_forgery with: :exception

  helper :all
  helper_method :current_user, :current_user_session

  def check_format
    if controller_name.to_s != "exceptions" and ["php", "zip"].include?(params[:format])
      # (RLC 4/23/19) It is not clear to me what purpose this check really serves:
      # so far as I know, "non-existent" routes generally return 404, not exceptions,
      # and if they do return exceptions, that generally means there is a bug in the
      # error handling code...
      #
      # However, at present, many application routes respond to ANY :format, including
      # .asdfajhdflahsfahjlf and arbitrary gobbledygook. We may want to readdress this:
      # https://stackoverflow.com/questions/1374415/how-to-limit-the-resource-formats-in-the-rails-routes-file.
      #
      # But, in the meantime, since the legacy comment says that bots targeting
      # zip and php were causing problems... let's continue manually forbidding
      # those two particular extensions so as not to invite problems.
      #
      # Legacy comment:
      #
      # This exists to prevent garbage exceptions in the Rails log caused by
      # spam links pointing to this non-existent route, and returns a 404 specifically
      # to detract from spam links' Google juice
      raise ActionController::RoutingError, 'Not Found'
    end
  end

  #Switch to local time zone
  def set_time_zone
    if current_user && ! current_user.tz_name.blank?
      Time.zone = current_user.tz_name
    end
  end

  def check_superadmin
    if current_user && current_user.superadmin?
      flash[:error] = "Admin Mode"
    end
  end

  private

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
