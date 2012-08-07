class UsersController < ApplicationController
  cache_sweeper :user_sweeper

  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:edit, :update, :bookmark_item, :dashboard, :require_user]
 
  def email_lookup
    @users = []
    @users << User.find_by_email_address(params[:user_lookup])
    @users << User.find_by_login(params[:user_lookup])
    @users = @users.compact.delete_if { |u| u.id == @current_user.id }
    render :json => { :users => @users }
  end

  def new
    @user = User.new
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

  def dashboard
    redirect_to "/" if !@current_user

    add_javascripts 'user_dashboard'
    add_stylesheets 'user_dashboard'
    @user = @current_user
  end

  def show
    params[:sort] ||= 'display_name'
    params[:order] ||= 'asc'

    set_sort_lists

    if params[:id] == 'create_anon'
      @user = @current_user
    else
      @user = User.find_by_id(params[:id])
    end

    #This is added for an optimization, to avoid lookup roles / authors of each item
    params[:sort] = 'name' if params[:sort] == 'display_name'

    if !request.xhr? || params[:ajax_region] == 'playlists'
      p = @user.playlists.sort_by { |p| p.send(params[:sort]).to_s.downcase }
      if(params[:order] == 'desc') 
        p = p.reverse
      end
      @collection = @playlists = p.paginate(:page => params[:page], :per_page => 25)
    end

    if !request.xhr? || params[:ajax_region] == 'collages'
      p = @user.collages.sort_by { |c| c.send(params[:sort]).to_s.downcase }
      if(params[:order] == 'desc') 
        p = p.reverse
      end
      @collection = @collages = p.paginate(:page => params[:page], :per_page => 25)
    end

    if !request.xhr? || params[:ajax_region] == 'cases'
      p = @user.cases.sort_by { |c| c.send(params[:sort]).to_s.downcase }
      if(params[:order] == 'desc') 
        p = p.reverse
      end
      @collection = @cases = p.paginate(:page => params[:page], :per_page => 25)
    end

    if current_user
      @is_case_admin = false #current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','case_admin','superadmin']}).length > 0
      @is_collage_admin = false #current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','collage_admin','superadmin']}).length > 0
    
      if current_user == @user
        @my_collages = @collages
        @my_playlists = @playlists
        @my_cases = @cases
      else
        @my_collages = @my_playlists = @my_cases = []
      end
    else
      @is_collage_admin = false
      @my_collages = @my_playlists = @my_cases = []
    end

    respond_to do |format|
      format.html do
        if request.xhr?
          @view = params[:ajax_region] == 'cases' ? 'case_obj' : params[:ajax_region].singularize
          render :partial => 'shared/generic_block'
        else
          render 'show'
        end
      end
    end
  end

  def edit
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

      base_model_klass = params[:type] == 'default' ? ItemDefault : params[:type].classify.constantize

      actual_object = base_model_klass.find(params[:id])

      if playlist.contains_item?(actual_object)
        render :json => { :already_bookmarked => true, :user_id => current_user.id }
      else
        klass = "item_#{params[:type]}".classify.constantize
        item = klass.new(:name => actual_object.bookmark_name,
          :url => params[:type] == 'default' ? actual_object.url : url_for(actual_object))
        item.actual_object = actual_object if params[:type] != 'default'
        item.save
        
        playlist_item = PlaylistItem.new(:playlist_id => playlist.id,
          :resource_item_type => "item_#{params[:type]}".classify,
          :resource_item_id => item.id)
        playlist_item.accepts_role!(:owner, current_user)
        playlist_item.save

        render :json => { :already_bookmarked => false, :user_id => current_user.id }
      end
    rescue Exception => e
      logger.warn "#{e.inspect}"
      render :status => 500, :json => {}
    end
  end
end
