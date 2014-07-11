class UsersController < ApplicationController
  cache_sweeper :user_sweeper
  before_filter :display_first_time_canvas_notice, :only => [:new, :create]
  protect_from_forgery :except => [:disconnect_dropbox, :disconnect_canvas]

  def new
    @user = User.new
  end

  def index
    common_index User
  end

  def verification_request
    if current_user.present? && current_user = User.where(id: params[:id]).first
      current_user.send_verification_request
      flash[:notice] = 'An email has been sent to you for account verification. Please stay logged in and visit the link in the email to verify your account.'
      redirect_to user_path(current_user)
    end
  end

  def verify
    if current_user.present? && current_user == User.where(id: params[:id]).first && params[:token] == current_user.perishable_token
      current_user.update_attribute(:verified, true)
      flash[:notice] = 'Thank you. Your account has been verified. You may now contribute to H2O.'
      redirect_to user_path(current_user)
      return
    end

    if current_user
      flash[:notice] = 'Your account has not been verified. Please try again by requesting an email verification <a href="' + verification_request_user_url(current_user)  + '" target="blank">here</a>.'
      redirect_to user_path(current_user)
    else
      flash[:notice] = 'Your account has not been verified. Please login and try visiting the link in the email again.'
      redirect_to '/user_sessions/new'
    end
  end

  def create
    @user = User.new(users_params)
    verify_captcha(@user)

    if @user.save
      @user.send_verification_request
      flash[:notice] = "Account registered! Please verify your account by clicking the link provided in the verification email."
      if first_time_canvas_login?
        save_canvas_id_to_user(@user)
        flash[:notice] += "<br/>Your canvas id was attached to this account.".html_safe
      end
      redirect_to user_path(@user)
    else
      render :action => :new
    end
  end

  def request_anon
    @user = User.new
  end

  def show
    set_sort_params
    set_sort_lists
    params[:page] ||= 1

    @user = params[:id] == 'create_anon' ? @current_user : User.where(id: params[:id]).first
    if @user.nil?
      redirect_to root_url, :status => 301
      return
    end

    if request.xhr? && params.has_key?("ajax_region")
      p = []
      if params["ajax_region"] == "case_requests"
        p = CaseRequest.all.sort_by { |p| p.send(params[:sort]).to_s.downcase }
      else
        p = @user.send(params["ajax_region"]).sort_by { |p| p.send(params[:sort]).to_s.downcase }
      end
      
      if(params[:order] == 'desc')
        p = p.reverse
      end
      @collection = p.paginate(:page => params[:page], :per_page => 10)
      render :partial => 'shared/generic_block'
      return
    elsif !params.has_key?("ajax_region")
      user_id_filter = @user.id
      public_filtering = !current_user || @user != current_user
      primary_filtering = false
      secondary_filtering = false
      bookmarks_id = @user.present? ? @user.bookmark_id : 0
     
      models = [Playlist, Collage, Case, Media, TextBlock, Default]
      if params.has_key?(:klass)
        if params[:klass] == 'medias'
          models = [Media]
        elsif params[:klass] == 'Primary'
          models = [Playlist]
          primary_filtering = true
        elsif params[:klass] == 'Secondary'
          models = [Playlist]
          secondary_filtering = true
        else
          models = [params[:klass].singularize.classify.constantize]
        end
      end

      @collection = Sunspot.new_search(models)
      @collection.build do
        paginate :page => params[:page], :per_page => 10
        with :user_id, user_id_filter

        if public_filtering
          with :public, true
          with :active, true
        end

        if primary_filtering
          with :primary, true
        end
        if secondary_filtering
          with :secondary, true
        end

        if params.has_key?(:within)
          keywords params[:within]
        end

        facet(:user_id)
        facet(:klass)
        facet(:primary)
        facet(:secondary)

        without :id, bookmarks_id

        order_by params[:sort].to_sym, params[:order].to_sym
      end

      @collection.execute!
      build_facet_display(@collection)
      b = @collection.facet(:primary).rows.detect { |r| r.value }
      @primary_playlists = b.count if b.present?
      b = @collection.facet(:secondary).rows.detect { |r| r.value }
      @secondary_playlists = b.count if b.present?

      if primary_filtering
        @klass_facets = []
      end
    end

    if !request.xhr?
      set_sort_lists
      @sort_lists[:all]["updated_at"] = @sort_lists[:all]["created_at"]
      @sort_lists[:all]["updated_at"][:display] = "SORT BY MOST RECENT ACTIVITY"
      @sort_lists[:all].delete "created_at"
      if params[:sort]
        @sort_lists[:all]["updated_at"][:selected] = true
      end
      if params["controller"] == "users" && params["action"] == "show"
        @sort_lists.each do |k, v|
          v.delete("user")
        end
      end

      @types = {
        :private_playlists_by_permission => {
          :display => false,
          :header => "Private Playlists",
          :partial => "playlist"
        },
        :pending_cases => {
          :display => false,
          :header => "Pending Cases",
          :partial => "pending_case"
        },
        :case_requests => {
          :display => false,
          :header => "Case Requests",
          :partial => "case_request"
        },
        :content_errors => {
          :display => false,
          :header => "Content Errors",
          :partial => "content_error"
        }
      }
      if current_user && @user == current_user
        @page_title = "Dashboard | H2O Classroom Tools"

        @paginated_bookmarks = @user.bookmarks.paginate(:page => params[:page], :per_page => 10)

        @types[:private_playlists_by_permission][:display] = true
        @types[:pending_cases][:display] = true

        if @user.has_role?(:case_admin)
          @types[:case_requests][:display] = true
        end

        if @user.has_role?(:superadmin)
          @types[:content_errors][:display] = true
        end
      else
        @page_title = "User #{@user.simple_display} | H2O Classroom Tools"
      end

      @types.each do |type, v|
        next if !v[:display]
        p = []

        if type == :case_requests
          p = CaseRequest.all.sort_by { |p| (p.respond_to?(params[:sort]) ? p.send(params[:sort]) : p.send(:display_name)).to_s.downcase }
        else
          p = @user.send(type).sort_by { |p| (p.respond_to?(params[:sort]) ? p.send(params[:sort]) : p.send(:display_name)).to_s.downcase }
        end

        if(params[:order] == 'desc')
          p = p.reverse
        end
        v[:results] = p.paginate(:page => params[:page], :per_page => 10)
      end
    end
    
    if request.xhr?
      render :partial => 'shared/generic_block'
    else
      render 'show'
    end
  end

  def edit
    if current_user && request.xhr?
      @user = current_user
    elsif current_user && !request.xhr?
      redirect_to "/users/#{current_user.id}"
    else
      redirect_to root_url
    end
  end

  def update
    @user = @current_user # makes our views "cleaner" and more consistent

    if @user.update_attributes(users_params)
      [:font, :font_size, :show_annotations].each do |f|
        cookies[f] = @user.send("default_#{f.to_s}")
      end
      profile_content = render_to_string("shared/_author_stats.html.erb", :locals => { :user => @user })
      settings_content = render_to_string("users/_settings.html.erb", :locals => { :user => @user })
      render :json => { :error => false, 
                        :custom_block => "update_user_settings", 
                        :settings_content => settings_content,
                        :profile_content => profile_content }
    else
      render :action => :edit
    end
  end

  def delete_bookmark_item
    if current_user.bookmark_id.nil?
      render :json => { :success => false, :message => "Error." }
      return
    end

    playlist_item_to_delete = PlaylistItem.where(playlist_id: current_user.bookmark_id, actual_object_type: params[:type].classify, actual_object_id: params[:id].to_i).first
    if playlist_item_to_delete && playlist_item_to_delete.destroy
      render :json => { :success => true }
    else
      render :json => { :success => false }
    end
  end

  def bookmark_item
    if current_user.bookmark_id.nil?
      playlist = Playlist.new({ :name => "Your Bookmarks", :public => false, :user_id => current_user.id })
      playlist.save
      current_user.update_attribute(:bookmark_id, playlist.id)
    else
      playlist = Playlist.where(id: current_user.bookmark_id).first
    end

    begin
      raise "not logged in" if !current_user

      klass = params[:type] == 'media' ? Media : params[:type].classify.constantize

      if playlist.contains_item?("#{klass.to_s}#{params[:id]}")
        render :json => { :already_bookmarked => true, :user_id => current_user.id }
      else
        actual_object = klass.where(id: params[:id]).first
        playlist_item = PlaylistItem.new(:playlist_id => playlist.id,
          :actual_object_type => actual_object.class.to_s,
          :actual_object_id => actual_object.id,
          :position => playlist.playlist_items.count,
          :name => actual_object.name)
        playlist_item.save

        render :json => { :already_bookmarked => false, :user_id => current_user.id }
      end
    rescue Exception => e
      logger.warn "#{e.inspect}"
      render :status => 500, :json => {}
    end
  end

  def user_lookup
    @users = User.where("(email_address = ? OR login = ?) AND id != ?", params[:lookup], params[:lookup], current_user.id).collect { |u| { :display => "#{u.login} (#{u.email_address})", :id => u.id } }
    render :json => { :items => @users }
  end

  def playlists
    render :json => { :playlists => User.where(id: params[:id]).first.playlists.select { |p| p.name != 'Your Bookmarks' }.to_json(:only => [:id, :name]) }
  end

  def disconnect_canvas
    @user = @current_user
    @user.update_attribute(:canvas_id, nil)
    redirect_to edit_user_path(@user)
    render :json => {}
  end

  def disconnect_dropbox
    @user = @current_user
    File.delete(@user.dropbox_access_token_file_path)
    render :json => {}
  end

  private
  def users_params
    params.require(:user).permit(:id, :name, :login, :password, :password_confirmation, 
                                 :email_address, :tz_name, :attribution, :title, 
                                 :url, :affiliation, :description, :tab_open_new_items, 
                                 :default_show_annotations, :default_font_size, :default_font, :terms)
  end
end
