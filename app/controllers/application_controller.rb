# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  include ExceptionNotification::ExceptionNotifiable
  #Comment out the line below if you want to see the normal rails errors in normal development.
  alias :rescue_action_locally :rescue_action_in_public if Rails.env == 'development'

  self.exception_notifiable_verbose = true #SEN uses logger.info, so won't be verbose in production
  self.exception_notifiable_silent_exceptions = [Acl9::AccessDenied, MethodDisabled, ActionController::RoutingError ]

  #specific errors can be handled by something else:

  rescue_from Acl9::AccessDenied, :with => :deny_access

  helper :all
  helper_method :current_user_session, :current_user
  filter_parameter_logging :password, :password_confirmation

  layout :layout_switch

  before_filter :fix_cookies
  before_filter :redirect_bad_format, :title_select, :set_time_zone
  before_filter :set_sort_params, :only => :index
  before_filter :set_sort_lists, :only => :index
  before_filter :set_page_cache_indicator
 
  #Add ability to make page caching conditional
  #to support only caching public items
  def self.caches_page(*actions)
    return unless perform_caching
    options = actions.extract_options!
    after_filter(:only => actions) { |c| c.cache_page if options[:if].nil? or options[:if].call(c) }
  end

  def redirect_bad_format
    if params[:format] == "php"
      redirect_to root_url, :status => 301
    end
  end

  #Switch to local time zone
  def set_time_zone
    if current_user && ! current_user.tz_name.blank?
      Time.zone = current_user.tz_name
    else
      Time.zone = DEFAULT_TIMEZONE 
    end
  end
  
  def set_page_cache_indicator
    @page_cache = false
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
    
    redirect_back_or_default "/"
  end

  def create_influence(original_object, spawned_object)
    original_influence = Influence.find_or_create_by_resource_id_and_resource_type(
      original_object.id, original_object.class.to_s)

    influence_record = Influence.new(:parent_id => original_influence.id)
    influence_record.resource = spawned_object
    influence_record.save!
  end

  # Note: set_sort_params should always execute before set_sort_lists
  # to ensure proper dropdown selected
  def set_sort_params
    if params.has_key?(:keywords)
      params[:sort] ||= "score"
    else
      if params[:controller] == "users" && params[:sort].nil?
        params[:sort] ||= "updated_at"
      else
        params[:sort] ||= "karma"
      end
    end

    params[:order] = (["score", "karma", "updated_at"].include?(params[:sort]) ? :desc : :asc) unless params[:order]
  end

  def verbose; true; end

  def set_sort_lists
    @sort_lists = {}
    base_sort = {
      "score" => { :display => "SORT BY RELEVANCE", :selected => true },
      "karma" => { :display => "SORT BY INFLUENCE", :selected => false },
      "display_name" => { :display => "SORT BY DISPLAY NAME", :selected => false }
    }
    @sort_lists[:all] = generate_sort_list(base_sort.merge({
      "decision_date" => { :display => "SORT BY DECISION DATE (IF APPLIES)", :selected => false },
      "created_at" => { :display => "SORT BY DATE CREATED", :selected => false },
      "user" => { :display => "SORT BY AUTHOR", :selected => false }
    }))
    @sort_lists[:cases] = @sort_lists[:pending_cases] = @sort_lists[:case_requests] = generate_sort_list(base_sort.merge({
      "decision_date" => { :display => "SORT BY DECISION DATE", :selected => false }
    }))
    @sort_lists[:text_blocks] = generate_sort_list(base_sort.merge({
      "user" => { :display => "SORT BY AUTHOR", :selected => false }
    }))
    if ["index", "search"].include?(params[:action])
      @sort_lists[:defaults] = @sort_lists[:playlists] = @sort_lists[:collages] = @sort_lists[:medias] = generate_sort_list(base_sort.merge({
        "created_at" => { :display => "SORT BY DATE", :selected => false },
        "user" => { :display => "SORT BY AUTHOR", :selected => false }
      }))
    else
      @sort_lists[:defaults] = @sort_lists[:playlists] = @sort_lists[:collages] = @sort_lists[:medias] = @sort_lists[:defects] = generate_sort_list(base_sort.merge({
        "created_at" => { :display => "SORT BY DATE", :selected => false }
      }))
    end
  end
 
  def common_index(model)
    set_belongings model

    @page_title = "#{model.to_s.pluralize} | H2O Classroom Tools"
    @model = model
    @label = model.to_s
    if model == Media
      @label = "Audio Items" if params[:media_type] == "audio"
      @label = "PDFs" if params[:media_type] == "pdf"
      @label = "Images" if params[:media_type] == "image"
      @label = "Videos" if params[:media_type] == "video"
      @page_title = "#{@label} | H2O Classroom Tools"
    elsif model == Default
      @label = "Links"
      @page_title = "Links | H2O Classroom Tools"
    elsif model == TextBlock
      @label = "Texts"
      @page_title = "Texts | H2O Classroom Tools"
    end
    @view = model == Case ? 'case_obj' : "#{model.to_s.downcase}"

    @partial = @model.to_s.downcase
    @partial = "case_obj" if @model == Case
    @model_sym = @partial.to_sym

    params[:page] ||= 1

    @collection = build_search(model, params)

    if @collection.results.total_entries <= 20 && @label == "Media"
      media_types = {}
      @collection.results.each do |hit|
        media_types[hit.media_type.label] = 1
      end
      if media_types.keys.length == 1
        @label = media_types.keys.first
        @label = "Audio Item" if @label == "Audio"
        @label = "#{@label}s" if @collection.results.total_entries != 1
        @page_title = "#{@label} | H2O Classroom Tools"
      end
    end


    if request.xhr?
      render :partial => 'shared/generic_block'
    else
      render 'shared/list_index'
    end
  end

  def build_search(model, params)
    items = (model == TextBlock ? Sunspot.new_search(TextBlock, JournalArticle) : Sunspot.new_search(model))
    
    items.build do
      if params.has_key?(:keywords)
        keywords params[:keywords]
      end
      if params.has_key?(:tags) && model != Case
        if params.has_key?(:any)
          any_of do
            params[:tags].each { |t| with :tag_list, t }
          end
        else
          params[:tags].each { |t| with :tag_list, t }
        end
      end
      if params.has_key?(:tag) && model != Case
        with :tag_list, CGI.unescape(params[:tag])
      end
      if params.has_key?(:media_type)
        with :media_type, params[:media_type]
      end

      if model == User
        with :anonymous, false  
      end
      if model == Playlist && current_user
        any_of do
          with :users_by_permission, current_user.login
          with :public, true
        end
      else
        with :public, true
      end

      with :active, true

      paginate :page => params[:page], :per_page => 20
      order_by params[:sort].to_sym, params[:order].to_sym
    end

    items.execute!
    items
  end

  def set_belongings(model)
    @my_belongings ||= {}
    @is_admin ||= {}

    if current_user
      admin_method = "is_#{model.to_s.downcase}_admin"
      @is_admin[model.to_s.downcase.to_sym] = current_user.respond_to?(admin_method) ? current_user.send(admin_method) : false
      @my_belongings[model.to_s.tableize.to_sym] = current_user.send(model.to_s.tableize.to_s)
    else
      @is_admin[model.to_s.downcase] = false
      @my_belongings[model.to_s.downcase] = []
    end
    if model == TextBlock
      @my_belongings[:textblocks] = @my_belongings[:text_blocks]
    end
  end

  protected

  def generate_sort_list(sort_fields)
    if params.has_key?(:sort)
      sort_fields.each do |k, v|
        v[:selected] = false
      end
      sort_fields.each do |k, v|
        if params[:sort] == k
          v[:selected] = true
        end
      end
    end

    sort_fields
  end

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
      
  # TODO: This handles the scenario where users with remember_me are auto logged in,
  # but cookies are not defined for them when auto logged in
  # Note: Can be moved to after auto login filter if one exists
  def fix_cookies
    if current_user.present? && cookies[:user_id].nil?
      apply_user_preferences(current_user)
    end
  end

  def apply_user_preferences(user)
    if user
      cookies[:font_size] = user.default_font_size
      cookies[:use_new_tab] = (user.tab_open_new_items? ? 'true' : 'false') 
      cookies[:show_annotations] = user.default_show_annotations
      cookies[:display_name] = user.simple_display
      cookies[:user_id] = user.id
      cookies[:anonymous_user] = false
      cookies[:bookmarks] = user.bookmarks_map.to_json
      cookies[:playlists] = user.playlists.size > 10 ? "force_lookup" : user.playlists.select { |p| p.name != 'Your Bookmarks' }.to_json(:only => [:id, :name]) 
    end
  end
  def destroy_user_preferences(user)
    [:font_size, :use_new_tab, :show_annotations, :display_name,
     :user_id, :anonymous_user, :bookmarks, :playlists].each do |attr|
      cookies.delete(attr)
    end
  end
 
  def verbose
    Rails.logger.warn "ApplicationController#verbose hit"
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
        flash[:notice] = "You must be logged in to access this page"
        redirect_to crossroad_user_session_url
        #redirect_to new_user_session_url
        return false
      end
    end

    def require_no_user
      if current_user
        flash[:notice] = "You must be logged out to access this page"
        redirect_to user_path(current_user)
        return false
      end
    end

    def redirect_back_or_default(default)
      redirect_to(cookies[:return_to] || default)
    end

    def update_question_instance_time
      if ! @UPDATE_QUESTION_INSTANCE_TIME.blank?
        @UPDATE_QUESTION_INSTANCE_TIME.updated_at = Time.now
        @UPDATE_QUESTION_INSTANCE_TIME.save
      end
    rescue Exception => e
      logger.warn("Couldn't update question instance id: #{@UPDATE_QUESTION_INSTANCE_TIME.id} because #{e.inspect}")
    end

    def restrict_if_private
      artifact = instance_variable_get("@#{controller_name.singularize.downcase}")
      return true if artifact.nil?
      if !artifact.public? and not current_user
        flash[:notice] = "You do not have access to this content."
        redirect_to crossroad_user_session_url
        return false
      elsif !artifact.public? and current_user and !(current_user.has_role?(:superadmin) || artifact.owner?)
        flash[:notice] = "You do not have access to this content."
        redirect_to crossroad_user_session_url
        return false
      else
        return true
      end
    end
end
