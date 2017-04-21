class UsersController < ApplicationController
  cache_sweeper :user_sweeper
  protect_from_forgery :except => [:disconnect_dropbox]
  layout 'main', only: [:new, :create, :show]

  DEFAULT_SHOW_TYPES = {
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
      :header => "Feedback",
      :partial => "content_error"
    },
    :user_responses => {
      :display => false,
      :header => "User Responses",
      :partial => "response"
    }
  }

  def new
    @user = User.new params.fetch(:user, {}).permit(:email_address, :attribution)
  end

  def index
    common_index User
  end

  # def verification_request
  #   if current_user.present? && current_user = User.where(id: params[:id]).first
  #     current_user.send_verification_request
  #     flash[:notice] = 'An email has been sent to you for account verification. Please stay logged in and visit the link in the email to verify your account.'
  #     redirect_to user_path(current_user)
  #   end
  # end

  # def verify
  #   if current_user.present? && current_user == User.where(id: params[:id]).first && params[:token] == current_user.perishable_token
  #     current_user.update_column(:verified, true)
  #     flash[:notice] = 'Thank you. Your account has been verified. You may now contribute to H2O.'
  #     redirect_to user_path(current_user)
  #     return
  #   end
  #   if current_user
  #     flash[:notice] = 'Your account has not been verified. Please try again by requesting an email verification <a href="' + verification_request_user_url(current_user)  + '" target="blank">here</a>.'
  #     redirect_to user_path(current_user)
  #   else
  #     flash[:notice] = 'Your account has not been verified. Please login and try visiting the link in the email again.'
  #     redirect_to '/user_sessions/new'
  #   end
  # end

  def create
    @user = User.new(users_params)
    verify_captcha(@user)

    if @user.save
      @user.send_verification_request_to_admin
      flash[:success] = I18n.t 'users.sign-up.flash.success.h'
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

    # TODO: Fix pagination for user bookmarks

    if !params.has_key?("ajax_region")
      user_id_filter = @user.id
      public_filtering = !(current_user && @user == current_user)
      primary_filtering = false
      secondary_filtering = false
      bookmarks_id = @user.present? ? @user.bookmark_id : 0

      models = [Playlist, Collage, Case, TextBlock, Default]

      if params.has_key?(:klass)
        if params[:klass] == 'Primary'
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

        order_by params[:sort].to_sym, params[:order].to_sym
      end

      @collection.execute!
      build_facet_display(@collection)

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

      build_user_page_content(params)
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
    @user = @current_user

    if @user.update_attributes(users_params)
      apply_user_preferences(@user, false, :force_overwrite => true)

      profile_content = render_to_string("shared/_author_stats.html.erb", :locals => { :user => @user })
      settings_content = render_to_string("users/_settings.html.erb", :locals => { :user => @user })

      render :json => {
        :error => false,
        :custom_block => "update_user_settings",
        :settings_content => settings_content,
        :profile_content => profile_content
      }
    else
      render :json => {
        :error => true,
        :message => "Could not update user, with errors: #{@user.errors.full_messages.join(', ')}"
      }
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
    playlist = current_user.bookmark_id.present? ? Playlist.where(id: current_user.bookmark_id).first : nil
    if playlist.nil?
      playlist = Playlist.new({ :name => "Your Bookmarks", :public => false, :user_id => current_user.id })
      playlist.valid_recaptcha = true
      playlist.save
      current_user.update_attribute(:bookmark_id, playlist.id)
    end

    begin
      klass = params[:type].classify.constantize

      if playlist.contains_item?("#{klass.to_s}#{params[:id]}")
        render :json => { :already_bookmarked => true, :user_id => current_user.id }
      else
        actual_object = klass.where(id: params[:id]).first
        playlist_item = PlaylistItem.new(:playlist_id => playlist.id,
          :actual_object_type => actual_object.class.to_s,
          :actual_object_id => actual_object.id,
          :position => playlist.playlist_items.count)
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

  def disconnect_dropbox
    @user = @current_user
    File.delete(@user.dropbox_access_token_file_path)
    render :json => {}
  end

  private
  def users_params
    common_attrs = common_user_preference_attrs.reject {|attr| attr == :user_id}
    params.fetch(:user, {}).permit(:id, :name, :login, :password, :password_confirmation,
                                 :email_address, :tz_name, :attribution, :title,
                                 :url, :affiliation, :description, :terms, *common_attrs
                                 )
  end

  def default_show_types_method
    {
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
        :header => "Feedback",
        :partial => "content_error"
      },
      :user_responses => {
        :display => false,
        :header => "User Responses",
        :partial => "response"
      }
    }
  end

  def build_user_page_content(params)
    @types = DEFAULT_SHOW_TYPES.dup
    # logger.warn "DEFAULT_SHOW_TYPES @types: #{@types}"
    # logger.warn "DEFAULT_SHOW_TYPES current_user: '#{current_user}'"
    # logger.warn "DEFAULT_SHOW_TYPES @user: '#{@user}'"

    #Reset @types to avoid the bug I suspect is lurking in production-only
    @types = default_show_types_method

    if current_user && @user == current_user
      # logger.warn "DEFAULT_SHOW_TYPES: option A"
      @page_title = "Dashboard | H2O Classroom Tools"
      @paginated_bookmarks = @user.bookmarks.paginate(:page => params[:page], :per_page => 10)

      @types[:pending_cases][:display] = true
      @types[:content_errors][:display] = true
      @types[:user_responses][:display] = true

      if @user.has_role?(:case_admin)
        @types[:case_requests][:display] = true
      end
    else
      # logger.warn "DEFAULT_SHOW_TYPES: option B"
      @page_title = "User #{@user.simple_display} | H2O Classroom Tools"
    end

    @types.each do |type, v|
      next if !v[:display]

      sorter = Proc.new {|j|
        (j.respond_to?(params[:sort]) ? j.send(params[:sort]) : j.send(:display_name)).to_s.downcase
      }
      if type == :case_requests
        content = CaseRequest.all.sort_by(&sorter)
      else
        content = @user.send(type).sort_by(&sorter)
      end

      if(params[:order] == 'desc')
        content.reverse!
      end

      v[:results] = content.paginate(:page => params[:page], :per_page => 10)
    end
  end

end
