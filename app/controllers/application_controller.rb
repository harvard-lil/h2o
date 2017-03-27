class ApplicationController < ActionController::Base
  include UserPreferenceExtensions
  # Important that check_auth happens after load_single_resource
  before_action :redirect_bad_format, :load_single_resource, :check_authorization_h2o,
                :fix_cookies, :set_time_zone, :set_page_cache_indicator
  before_action :set_sort_params, :only => [:index, :tags]
  before_action :set_sort_lists, :only => [:index, :tags]
  before_action :filter_tag_list, :only => [:update, :create]

  after_filter :allow_iframe

  layout :layout_switch

  protect_from_forgery with: :exception

  helper :all
  helper_method :current_user_session, :current_user, :iframe?

  # Layout is always false for ajax calls
  def layout_switch
    return false if request.xhr?
  end

  def filter_tag_list
    return if !["collages", "defaults", "playlists", "medias", "text_blocks"].include?(params[:controller])

    resource_type = params[:controller].gsub(/s$/, '').to_sym
    return if params[resource_type].nil?

    return if params[resource_type][:tag_list].nil?

    params[resource_type][:tag_list].gsub!(/,/, '::::')
  end

  def load_single_resource
    return if ['user_sessions', 'password_resets', 'login_notifiers', 'base', 'pages', 'rails_admin/main'].include?(params[:controller])

    return if params[:controller] == 'users' && !['edit', 'update'].include?(params[:action])

    if params[:action] == "new"
      model = params[:controller] == "medias" ? Media : params[:controller].singularize.classify.constantize
      @single_resource = item = model.new
      if model == Media
        @media = item
      else
        instance_variable_set "@#{model.to_s.tableize.singularize}", item
      end
      @page_title = "New #{model.to_s}"
    elsif params[:id].present?
      model = params[:controller] == "medias" ? Media : params[:controller].singularize.classify.constantize
      if params[:action] == "new"
        item = model.new
      elsif ["access_level", "save_readable_state"].include?(params[:action])
        item = model.unscoped.where(id: params[:id].to_i).includes(:user).first
      elsif model.respond_to?(:get_single_resource)
        item = model.get_single_resource(params[:id])
      else
        item = model.where(id: params[:id]).first
      end
      if item.present? && item.is_a?(User)
        @single_resource = item
      elsif item.present? && ((item.respond_to?(:user) && item.user.present?) || item.is_a?(Annotation))
        @single_resource = item
        if params[:controller] == "medias"
          @media = item
        else
          instance_variable_set "@#{model.to_s.tableize.singularize}", item
        end
        @page_title = item.name if item.respond_to?(:name)
      else
        render :file => "#{Rails.root}/public/404.html", :status => 404, :layout => false
      end
    end
  end

  def action_check
    params.fetch(:action).to_sym
  end

  def check_authorization_h2o
    return true if params[:controller] == "rails_admin/main"

    if @single_resource.present?
      authorize! action_check, @single_resource
    else
      authorize! action_check, params[:controller].to_sym
    end

    return true
  end

  def redirect_bad_format
    if params[:format] == "php"
      # Note: This has to be hardcoded, not root_url
      redirect_to "/", :status => 301
      true
    elsif params[:format] == "zip"
      # This exists to prevent garbage exceptions in the Rails log caused by
      # spam links pointing to this non-existent route, and returns a 404 specifically
      # to detract from spam links' Google juice
      render :text => "Not found", :status => 404, :layout => false
      true
    end
  end

  #Switch to local time zone
  def set_time_zone
    if current_user && ! current_user.tz_name.blank?
      Time.zone = current_user.tz_name
    end
  end

  def set_page_cache_indicator
    @page_cache = false
  end

  # Note: set_sort_params should always execute before set_sort_lists
  # to ensure proper dropdown selected
  def set_sort_params
    if !["updated_at", "score", "display_name", "decision_date", "created_at", "user"].include?(params[:sort])
      params[:sort] = nil
    end

    if params.has_key?(:keywords)
      params[:sort] ||= "score"
    else
      if params[:controller] == "users" && params[:sort].nil?
        params[:sort] ||= "updated_at"
      else
        params[:sort] ||= "display_name"
      end
    end

    if !params.has_key?(:order) && ["score", "updated_at", "created_at"].include?(params[:sort])
      params[:order] = "desc"
    end
    if !["asc", "desc", "ascending", "descending"].include?(params[:order])
      params[:order] = :asc
    end
  end

  def set_sort_lists
    @sort_lists = {}
    base_sort = {
      "display_name" => { :display => "SORT BY DISPLAY NAME", :selected => false },
      "score" => { :display => "SORT BY RELEVANCE", :selected => true }
    }
    @sort_lists[:all] = generate_sort_list(base_sort.merge({
      "decision_date" => { :display => "SORT BY DECISION DATE (IF APPLIES)", :selected => false },
      "created_at" => { :display => "SORT BY DATE CREATED", :selected => false },
      "user" => { :display => "SORT BY AUTHOR", :selected => false }
    }))
    @sort_lists[:cases] = generate_sort_list(base_sort.merge({
      "decision_date" => { :display => "SORT BY DECISION DATE", :selected => false }
    }))
    @sort_lists[:pending_cases] = @sort_lists[:case_requests] = {
      "display_name" => { :display => "SORT BY DISPLAY NAME", :selected => false },
      "decision_date" => { :display => "SORT BY DECISION DATE", :selected => false }
    }
    @sort_lists[:users] = base_sort
    @sort_lists[:text_blocks] = generate_sort_list(base_sort.merge({
      "user" => { :display => "SORT BY AUTHOR", :selected => false }
    }))
    if ["index", "search"].include?(params[:action])
      @sort_lists[:defaults] = @sort_lists[:playlists] = @sort_lists[:collages] = @sort_lists[:medias] = @sort_lists[:media] = generate_sort_list(base_sort.merge({
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
    @page_title = "#{params.has_key?(:featured) ? "Featured " : ""}#{model.to_s.pluralize} | H2O Classroom Tools"
    @type_lookup = model == Media ? :medias : model.to_s.tableize.to_sym
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
    elsif model == Collage
      @page_title = "Annotated Items | H2O Classroom Tools"
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
    items = (model == User ? User.search : (model.is_a?(Array) ? Sunspot.new_search(model) : model.search(:include => :user)))

    items.build do
      if params.has_key?(:klass)
        if params[:klass] == "Primary"
          with :klass, "Playlist"
          with :primary, true
        elsif params[:klass] == "Secondary"
          with :klass, "Playlist"
          with :secondary, true
        else
          with :klass, params[:klass]
        end
      end
      if params.has_key?(:user_ids)
        user_ids = params[:user_ids].split(',')
        any_of do
          user_ids.each { |k| with :user_id, k }
        end
      end
      if params.has_key?(:annotype)
        with :annotype, params[:annotype]
      end
      if params.has_key?(:keywords)
        keywords params[:keywords]
      end
      if params.has_key?(:within)
        keywords params[:within]
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

      if model == Playlist && current_user
        any_of do
          with :users_by_permission, current_user.login
          with :public, true
        end
      else
        with :public, true
      end

      if [Collage,Playlist].include?(model) && params.has_key?(:featured)
        with :featured, true
      end

      facet(:user_id)
      facet(:klass)
      if model != User
        facet(:primary)
        facet(:secondary)
      end
      if model == Collage
        facet(:annotype)
      end

      paginate :page => params[:page], :per_page => params[:per_page]
      order_by params[:sort].to_sym, params[:order].to_sym
    end

    begin
      items.execute!
      build_facet_display(items) if model != User
    rescue => e
      # Return empty search results rather than blow up on user
      items = User.search { with :user_id, nil }
      logger.warn "Rescued search error: #{e}"
    end
    items
  end

  def build_facet_display(collection)
    @display_drilldown = true
    @user_facet_display = []
    @klass_facet_display = []
    @annotype_facet_display = {}
    @queued_users = []
    @klass_label_map = {
      'Default' => 'Link',
      'UserCollection' => 'User Collection',
      'TextBlock' => 'Text',
      'Collage' => 'Annotated Item'
    }

    if collection.results.total_entries == 0
      if params.has_key?(:user_ids)
        u = User.where(id: params[:user_ids])
        @user_facet_display << { :user => u.first, :count => 0, :class => '' } if u.present?
      end
      if params.has_key?(:klass)
        @klass_facet_display << { :value => params[:klass], :count => 0 }
      end
      return
    else
      if params[:controller] != "users" && current_user && !(params.has_key?(:user_ids) && params[:user_ids].to_i != current_user.id)
        b = collection.facet(:user_id).rows.detect { |b| b.value == current_user.id }
        @user_facet_display << { :user => current_user, :class => 'current_user', :count => b.present? ? b.count : 0 }
      end

      if collection.facet(:annotype).present?
        collection.facet(:annotype).rows.each do |row|
          @annotype_facet_display[row.value.to_s.downcase.to_sym] = row.count
        end
      end

      collection.facet(:user_id).rows.each do |row|
        next if [606, 0].include?(row.value)
        next if current_user && row.value == current_user.id
        if @user_facet_display.size < 5
          u = User.where(id: row.value)
          @user_facet_display << { :user => u.first, :count => row.count, :class => '' } if u.present?
        else
          @queued_users << { :id => row.value, :count => row.count }
        end
      end

      collection.facet(:klass).rows.each do |row|
        @klass_facet_display << { :value => row.value, :count => row.count }
      end
    end

    b = collection.facet(:primary).rows.detect { |r| r.value }
    @primary_playlists = b.count if b.present?
    b = collection.facet(:secondary).rows.detect { |r| r.value }
    @secondary_playlists = b.count if b.present?

    if params.has_key?(:klass) && params[:klass] == 'PrimaryPlaylist'
      @klass_facet_display.delete_if { |a| a[:value] == 'Playlist' }
    end
    if params.has_key?(:user_ids)
      @user_facet_display.each { |b| b[:class] = "#{b[:class]} active" }
    end

    @klass_facets = collection.facet(:klass).rows
  end

  def export_as
    base_args = {
      request_url: request.url,
      params: params,
      session_cookie: cookies[:_h2o_session],
    }
    if request.xhr?
      export_content_async(base_args)
    else
      export_content(base_args)
    end
  end

  protected

  def strip_html_tags(string)
    Loofah.fragment(string).scrub!(:strip).to_text
  end

  def export_content_async(base_args)
    logger.warn "XHR request for export_as with base_args: #{base_args.inspect}"
    if !current_user
      render :text => "Sorry. Export is available for logged in users only."
      return
    end

    render :json => {}
    base_args[:email_to] = current_user.email_address
    PlaylistExporter.delay.export_as(base_args)
  end

  def export_content(base_args)
    logger.warn "Sync request for export_as with base_args: #{base_args.inspect}"
    result = PlaylistExporter.export_as(base_args)
    if result.success?
      send_file(result.content_path, filename: result.suggested_filename)
    else
      logger.warn "Export failed: #{result.error_message}"
      render :text => result.error_message
    end
  end

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

  # This handles the scenario where users with remember_me are auto logged in,
  # but cookies are not defined for them when auto logged in
  # TODO: Can be moved to after auto login filter if one exists
  def fix_cookies
    if current_user.present? && cookies[:user_id].nil?
      apply_user_preferences(current_user, false)
    end
  end

  def verbose
    Rails.logger.warn "ApplicationController#verbose hit"
  end

  def limit_missing_item
    @single_resource.playlist_items.each do |playlist_item|
      if playlist_item.playlist.user == @single_resource.user
        playlist_item.destroy
      end
    end

    playlist_users = @single_resource.playlist_items.collect { |pi| pi.playlist.user_id }.uniq
    if playlist_users.detect { |u| u != @single_resource.user_id }
      @single_resource.update_attributes({ :user_id => 101022 })
      render :json => {}
    else
      # Do nothing, continue with deletion of item
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

  def verify_captcha(item)
    # NOTE: verify_recaptcha is from the recaptcha gem
    # if verify_recaptcha(:model => item, :message => '')
    #   item.valid_recaptcha = true
    # end
  end

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.record
  end

  def display_first_time_canvas_notice
    if first_time_canvas_login?
      notice =
        "You are logging into H2o directly from Canvas for the first time.<br/><br/>
         After you login your Canvas id will be attached to your H2o id
         and the next time you initiate an H2o session from Canvas you'll be logged in
         automatically."
      if flash[:notice].blank?
        flash[:notice] = notice.html_safe
      else
        flash[:notice] = flash[:notice].html_safe + "<br/><br/>#{notice}".html_safe
      end
    end
  end
  def redirect_back_or_default(default)
    redirect_to(cookies[:return_to] || default)
  end
  def first_time_canvas_login?
    session.key?(:canvas_user_id)
  end

  def save_canvas_id_to_user(user)
    user.update_attribute(:canvas_id, session.fetch(:canvas_user_id))
    clear_canvas_id_from_session
  end

  def clear_canvas_id_from_session
    session[:canvas_user_id] = nil
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
