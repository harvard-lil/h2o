class ApplicationController < ActionController::Base
  # Important that check_auth happens after load_single_resource
  before_filter :redirect_bad_format, :load_single_resource, :check_authorization,
                :fix_cookies, :set_time_zone, :set_page_cache_indicator
  before_filter :set_sort_params, :only => [:index, :tags]
  before_filter :set_sort_lists, :only => [:index, :tags]

  layout :layout_switch

  protect_from_forgery with: :exception

  helper :all
  helper_method :current_user_session, :current_user

  # Layout is always false for ajax calls
  def layout_switch
    request.xhr? ? false : "application"
  end

  def check_authorization
    current_user_roles = current_user.present? ? current_user.roles.map { |r| r.name } : []
    # Superadmin can do everything
    if current_user.present? && current_user_roles.include?("superadmin")
      return true
    end
    # Cases admin can do everything on cases controller
    if current_user.present? && current_user_roles.include?("case_admin") && params[:controller].match(/^case/).present?
      return true
    end

    return true if params[:controller] == "bulk_uploads" && current_user.present?

    # allow index, embedded_pager
    return true if @single_resource.nil? && params[:controller] != "playlist_items"

    # if playlist item is created, allow owner of playlist to add
    if params[:controller] == "playlist_items" && request.post? && params.has_key?(:playlist_item)
      playlist = Playlist.where(id: params[:playlist_item][:playlist_id]).first
      if current_user.present? && playlist.user.present? && playlist.user == current_user
        return true
      end
    end

    # owner of resource can do all on single resource
    if current_user.present? && @single_resource.user == current_user
      return true
    end

    # many methods can be done if item is public
    if @single_resource.present? && @single_resource.public? && [:show, :layers, :export, :export_unique, :access_level].include?(params[:action].to_sym)
      return true
    end

    # allow logged in users to new, create, copy, deep copy
    if current_user.present? && [:new, :create, :copy, :deep_copy].include?(params[:action].to_sym)
      return true
    end

    # various whitelisting based on user collections
    if current_user.present?
      if params[:controller] == "annotations"
        if [:destroy, :edit, :update].include?(params[:action].to_sym) && current_user.can_permission_collage("edit_annotations", @single_resource.collage)
          return true
        end
      elsif params[:controller] == "collages"
        if [:edit, :update].include?(params[:action].to_sym) && current_user.can_permission_collage("edit_collage", @single_resource)
          return true
        end
      elsif params[:controller] == "playlists"
        if [:notes].include?(params[:action].to_sym) && current_user.can_permission_playlist("edit_notes", @single_resource)
          return true
        end
        if [:edit, :update].include?(params[:action].to_sym) && current_user.can_permission_playlist("edit_description", @single_resource)
          return true
        end
      end
    end

    # if not passed whitelist accessibility,
    # redirect on no access
    flash[:notice] = "You do not have access to this content."
    if request.xhr?
      render :json => {}
    elsif current_user.present?
      redirect_to user_path(current_user)
    else
      redirect_to new_user_session_path
    end
    return false
  end

  def redirect_bad_format
    if params[:format] == "php"
      # Note: This has to be hardcoded, not root_url
      redirect_to "/", :status => 301
    end
  end

  #Switch to local time zone
  def set_time_zone
    if current_user && ! current_user.tz_name.blank?
      Time.zone = current_user.tz_name
    #else
    #  Time.zone = DEFAULT_TIMEZONE
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
    if params[:sort] == "decision_date" && params[:filter_type] != "cases"
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

    params[:order] = (["score", "updated_at"].include?(params[:sort]) ? :desc : :asc) unless params[:order]
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
    @sort_lists[:cases] = @sort_lists[:pending_cases] = @sort_lists[:case_requests] = generate_sort_list(base_sort.merge({
      "decision_date" => { :display => "SORT BY DECISION DATE", :selected => false }
    }))
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
    set_belongings model if model != User

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

      if model == Playlist && current_user
        any_of do
          with :users_by_permission, current_user.login
          with :public, true
        end
      else
        with :public, true
      end

      with :active, true

      paginate :page => params[:page], :per_page => params[:per_page]
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
      @my_belongings[model.to_s.tableize.to_sym] = model == Media ? current_user.medias : current_user.send(model.to_s.tableize.to_s)
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

  # This handles the scenario where users with remember_me are auto logged in,
  # but cookies are not defined for them when auto logged in
  # TODO: Can be moved to after auto login filter if one exists
  def fix_cookies
    if current_user.present? && cookies[:user_id].nil?
      apply_user_preferences(current_user, false)
    end
  end

  def apply_user_preferences(user, on_create)
    if user
      cookies[:font_size] = user.default_font_size
      cookies[:use_new_tab] = (user.tab_open_new_items? ? 'true' : 'false')
      cookies[:show_annotations] = user.default_show_annotations
      cookies[:display_name] = user.simple_display
      cookies[:user_id] = user.id
      cookies[:anonymous_user] = false

      if on_create
        cookies[:bookmarks] = "[]"
        cookies[:playlists] = "[]"
      else
        cookies[:bookmarks] = user.bookmarks_map.to_json
        cookies[:playlists] = user.playlists.size > 10 ? "force_lookup" : user.playlists.select { |p| p.name != 'Your Bookmarks' }.to_json(:only => [:id, :name])
      end
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
  def verify_captcha(item)
    if verify_recaptcha(:model => item, :message => '')
      item.valid_recaptcha = true
    end
  end

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.record
  end

  def load_single_resource
    return if ['user_sessions', 'users', 'password_resets', 'login_notifiers', 'base', 'pages', 'rails_admin/main'].include?(params[:controller])

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
      item = params[:action] == "new" ? model.new : model.where(:id => params[:id]).first
      if item.present? && item.user.present?
        @single_resource = item
        if params[:controller] == "medias"
          @media = item
        else
          instance_variable_set "@#{model.to_s.tableize.singularize}", item
        end
        @page_title = item.name
      else
        render :file => "#{Rails.root}/public/404.html", :status => 404, :layout => false
      end
    end
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
end
