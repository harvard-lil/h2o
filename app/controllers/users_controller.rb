class UsersController < ApplicationController
  cache_sweeper :user_sweeper

  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:edit, :update, :bookmark_item, :delete_bookmark_item, :require_user]
  before_filter :create_brain_buster, :only => [:new]
  before_filter :validate_brain_buster, :only => [:create]
 
  def new
    @user = User.new
  end

  def index
    common_index User    
  end

  def render_or_redirect_for_captcha_failure
    @user = User.new(params[:user])
    @user.valid?
    @user.errors.add_to_base("Your captcha answer failed - please try again.")
    create_brain_buster
    render :action => "new"
  end
  
  def create
    @user = User.new(params[:user])
    
    @user.save do |result|
      if result
        flash[:notice] = "Account registered!"
        redirect_back_or_default "/"
      else
        render :action => :new
      end
    end
  end

  def create_anon
    password = ActiveSupport::SecureRandom.random_bytes(10)
    user = User.new(:login => "anon_#{ActiveSupport::SecureRandom.hex(13)}",
      :password => password,
      :password_confirmation => password)
    user.has_role! :nonauthenticated
    user.save do |result|
      if result
        apply_user_preferences(user, true)
        cookies[:anonymous_user] = true
        cookies[:display_name] = "ANONYMOUS"
        if request.xhr?
          #text doesn't matter, it's the return code that does
          render :text => '/'
          return
        else
          flash[:notice] = "Account registered!"
          redirect_back_or_default user_path(user)
          return
        end
      else
        render :action => :create_anon, :status => :unprocessable_entity
        return
      end
    end
          
    redirect_back_or_default "/"
  end

  def show
    set_sort_params
    set_sort_lists
    params[:page] ||= 1

    @user = params[:id] == 'create_anon' ? @current_user : User.find_by_id(params[:id])
    user_id_filter = @user.id

    public_filtering = !current_user || @user != current_user

    models = params.has_key?(:filter_type) ? [params[:filter_type].singularize.classify.constantize] : [Playlist, Collage, Case, Media, TextBlock, Default]  
    models.each do |model|
      set_belongings model
    end

    if request.xhr?
      if params.has_key?("ajax_region")
	      p = @user.send(params["ajax_region"]).sort_by { |p| p.send(params[:sort]).to_s.downcase }
	      if(params[:order] == 'desc') 
	        p = p.reverse
	      end
	      @collection = p.paginate(:page => params[:page], :per_page => 10)
        @view = params[:ajax_region] == 'cases' ? 'case_obj' : params[:ajax_region].singularize

        if params[:ajax_region] == "bookmarks"
          render :partial => 'shared/bookmarks_block'
        else
          render :partial => 'shared/generic_collection_block'
        end
      else
        @results = Sunspot.new_search(models)
        @results.build do
          paginate :page => params[:page], :per_page => 10 
          with :user_id, user_id_filter

          if public_filtering
            with :public, true
            with :active, true
          end

          if params.has_key?(:keywords)
            keywords params[:keywords]
          end

          order_by params[:sort].to_sym, params[:order].to_sym
        end
        @results.execute!
        render :partial => 'base/search_ajax'
      end
    else
      bookmarks_id = @user.bookmark_id || 0
      @bookshelf = Sunspot.new_search(models)
      @bookshelf.build do
        paginate :page => params[:page], :per_page => 10 
        with :user_id, user_id_filter
          
        if public_filtering
          with :public, true
          with :active, true
        end

        if params.has_key?(:keywords)
          keywords params[:keywords]
        end

        #TODO: This is buggy, limit this filter to type playlist
        without :id, bookmarks_id

        order_by params[:sort].to_sym, params[:order].to_sym
      end
      @bookshelf.execute!

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
	      if @user.is_case_admin
	        @types[:case_requests][:display] = true
	        @my_belongings[:case_requests] = current_user.case_requests
	      end
	      if @user.is_admin
	        @types[:content_errors][:display] = true
	      end
	    else
	      @page_title = "User #{@user.simple_display} | H2O Classroom Tools"
	    end

	    add_javascripts 'user_dashboard'
	    add_stylesheets 'user_dashboard'

	    @types.each do |type, v|
        next if !v[:display]
	      p = @user.send(type).sort_by { |p| (p.respond_to?(params[:sort]) ? p.send(params[:sort]) : p.send(:display_name)).to_s.downcase }

	      if(params[:order] == 'desc') 
	        p = p.reverse
	      end
	      v[:results] = p.paginate(:page => params[:page], :per_page => 10)
	    end
      render 'show'
    end
  end

  def edit
    @page_title = "User Edit | H2O Classroom Tools"
    @user = @current_user
  end

  def has_voted_for
    votes = current_user.votes.find(:all, :conditions => ['voteable_type = ?',params[:id]]).collect{|v|v.voteable_id}
    hash = {}
    votes.each{|v| hash[v] = true}
    render :json => hash
  rescue Exception => e
    render :json => {}
  end
  
  def update
    @user = @current_user # makes our views "cleaner" and more consistent

    if @user.update_attributes(params[:user])
      cookies[:show_annotations] = @user.default_show_annotations
      flash[:notice] = "Account updated!"
      redirect_to user_path(@user)
    else
      render :action => :edit
    end
  end

  # post delete_bookmark_item/:type/:id
  def delete_bookmark_item
    if current_user.bookmark_id.nil?
      render :json => { :success => false, :message => "Error." }
      return
    end

    playlist_item_to_delete = PlaylistItem.find_by_playlist_id_and_actual_object_type_and_actual_object_id(current_user.bookmark_id, params[:type].classify, params[:id].to_i) 
      
    if playlist_item_to_delete && playlist_item_to_delete.destroy
      render :json => { :success => true }
    else
      render :json => { :success => false }
    end
  end

  # post bookmark_item/:type/:id
  def bookmark_item
    if current_user.bookmark_id.nil?
      playlist = Playlist.new({ :name => "Your Bookmarks", :title => "Your Bookmarks", :public => false, :user_id => current_user.id })
      playlist.save
      current_user.update_attribute(:bookmark_id, playlist.id)
    else
      playlist = Playlist.find(current_user.bookmark_id)
    end

    begin
      raise "not logged in" if !current_user

      klass = params[:type] == 'media' ? Media : params[:type].classify.constantize

      if playlist.contains_item?("#{klass.to_s}#{params[:id]}")
        render :json => { :already_bookmarked => true, :user_id => current_user.id }
      else
        actual_object = klass.find(params[:id])
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
    @users = []
    @users << User.find_by_email_address(params[:lookup])
    @users << User.find_by_login(params[:lookup])
    @users = @users.compact.delete_if { |u| u.id == @current_user.id }.collect { |u| { :display => "#{u.login} (#{u.email_address})", :id => u.id } } 
    render :json => { :items => @users }
  end

  def playlists
    render :json => { :playlists => User.find(params[:id]).playlists.select { |p| p.name != 'Your Bookmarks' }.to_json(:only => [:id, :name]) } 
  end
end
