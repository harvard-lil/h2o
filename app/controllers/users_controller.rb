class UsersController < ApplicationController
  cache_sweeper :user_sweeper

  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:edit, :update, :bookmark_item, :require_user]
  before_filter :create_brain_buster, :only => [:new]
  before_filter :validate_brain_buster, :only => [:create]
 
  def new
    @user = User.new
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
        redirect_back_or_default "/base"
      else
        render :action => :new
      end
    end
  end

  def create_anon
    password = ActiveSupport::SecureRandom.random_bytes(10)
    @user = User.new(:login => "anon_#{ActiveSupport::SecureRandom.hex(13)}",
      :password => password,
      :password_confirmation => password)
    @user.has_role! :nonauthenticated
    @user.save do |result|
      if result
        if request.xhr?
          #text doesn't matter, it's the return code that does
          render :text => (session[:return_to] || '/')
        else
          flash[:notice] = "Account registered!"
          redirect_back_or_default user_path(@user)
        end
      else
        render :action => :create_anon, :status => :unprocessable_entity
      end
    end
  end

  def show
    set_sort_params
    set_sort_lists
    params[:page] ||= 1

    @user = params[:id] == 'create_anon' ? @current_user : User.find_by_id(params[:id])
    author_filter = @user.login.downcase

    [Playlist, Collage, Case, Media, TextBlock, Default].each do |model|
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
          render :partial => 'shared/generic_block'
        end
      else
        @results = Sunspot.new_search(Playlist, Collage, Case, Media, TextBlock)
        @results.build do
          paginate :page => params[:page], :per_page => 10 
          with :author, author_filter
          with :public, true
          with :active, true

          order_by params[:sort].to_sym, params[:order].to_sym
        end
        @results.execute!
        render :partial => 'base/search_ajax'
      end
    else
      @bookshelf = Sunspot.new_search(Playlist, Collage, Case, Media, TextBlock)
      @bookshelf.build do
        paginate :page => params[:page], :per_page => 10 
        with :author, author_filter
        with :public, true
        with :active, true

        order_by params[:sort].to_sym, params[:order].to_sym
      end
      @bookshelf.execute!

      set_sort_lists
      if params["controller"] == "users" && params["action"] == "show"
        @sort_lists.each do |k, v|
          v.delete("score")
        end
      end

	    @types = []
	    if current_user && @user == current_user
	      @page_title = "Dashboard | H2O Classroom Tools"

	      @paginated_bookmarks = @user.bookmarks.paginate(:page => params[:page], :per_page => 10)

	      if @user.is_case_admin
	        @types += [:case_requests, :pending_cases]
	        @my_belongings[:case_requests] = current_user.case_requests
	      else
	        @types << :pending_cases
	      end
	      if @user.is_admin
	        @types += [:content_errors]
	      end
	    else
	      @page_title = "User #{@user.simple_display} | H2O Classroom Tools"
	    end

	    add_javascripts 'user_dashboard'
	    add_stylesheets 'user_dashboard'

	    @results = {}
	    @types.each do |type|
	      p = @user.send(type).sort_by { |p| (p.respond_to?(params[:sort]) ? p.send(params[:sort]) : p.send(:display_name)).to_s.downcase }

	      if(params[:order] == 'desc') 
	        p = p.reverse
	      end
	      @results[type] = p.paginate(:page => params[:page], :per_page => 10)
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
      flash[:notice] = "Account updated!"
      redirect_to user_path(@user)
    else
      render :action => :edit
    end
  end

  # post bookmark_item/:type/:id
  def bookmark_item
    if current_user.bookmark_id.nil?
      playlist = Playlist.new({ :name => "Your Bookmarks", :title => "Your Bookmarks", :public => false })
      playlist.save
      playlist.accepts_role!(:owner, current_user)
      playlist.accepts_role!(:creator, current_user)
      current_user.update_attribute(:bookmark_id, playlist.id)
    else
      playlist = Playlist.find(current_user.bookmark_id)
    end

    begin
      raise "not logged in" if !current_user

      klass = nil
      if params[:type] == 'media'
        klass = Media
      else
        klass = params[:type].classify.constantize
      end

      actual_object = klass.find(params[:id])

      if playlist.contains_item?(actual_object)
        render :json => { :already_bookmarked => true, :user_id => current_user.id }
      else
        item_klass = "Item#{klass.to_s}".constantize

        item = item_klass.new(:name => actual_object.respond_to?(:name) ? actual_object.name : actual_object.bookmark_name,
          :url => url_for(actual_object))
        item.actual_object = actual_object
        item.save

        playlist_item = PlaylistItem.new(:playlist_id => playlist.id,
          :resource_item_type => item_klass.to_s,
          :resource_item_id => item.id)
        playlist_item.accepts_role!(:owner, current_user)
        playlist_item.save

        Rails.logger.warn "stephie: #{playlist_item.inspect}"

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
end
