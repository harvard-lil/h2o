class UsersController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:edit, :update, :bookmark_item]
  
  def new
    @user = User.new
  end
  
  def create
    @user = User.new(params[:user])
    
    @user.save do |result|
      if result
        flash[:notice] = "Account registered!"
        redirect_back_or_default user_path(@user)
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
    if params[:id] == 'create_anon'
	  @user = @current_user
	else
      @user = User.find_by_id(params[:id])
	end

	if !params.has_key?(:sort)
	  params[:sort] = "display_name"
	end

	#o.replace(o.gsub!(/\W+/, '')) --- add if remove non-word characters for sort

    if !params.has_key?(:is_ajax) || params[:is_ajax] == 'playlists'
	  @playlists = @user.playlists.sort_by { |p| p.send(params[:sort]).to_s.downcase }.paginate :page => params[:page], :per_page => cookies[:per_page] || nil
	end

    if !params.has_key?(:is_ajax) || params[:is_ajax] == 'collages'
	  @collages = @user.collages.sort_by { |c| c.send(params[:sort]).to_s.downcase }.paginate :page => params[:page], :per_page => cookies[:per_page] || nil
	end

    if !params.has_key?(:is_ajax) || params[:is_ajax] == 'cases'
 	  @cases = @user.cases.sort_by { |c| c.send(params[:sort]).to_s.downcase }.paginate :page => params[:page], :per_page => cookies[:per_page] || nil
	end

	if !params.has_key?(:is_ajax)
	  generate_sort_list({"display_name" 	=> 'DISPLAY NAME',
			"created_at"	=> 'BY DATE' })
	end

	if current_user
      @is_case_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','case_admin','superadmin']}).length > 0
	  @is_collage_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','collage_admin','superadmin']}).length > 0
	  @playlist_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','playlist_admin','superadmin']}).length > 0
      @playlists_i_can_edit = current_user.playlists_i_can_edit
	
	  if current_user == @current_user
	    @my_collages = @collages
	    @my_playlists = @playlists
		@my_cases = @cases
	  end
	else
	  @is_collage_admin = false
	  @my_collages = []
	  @my_playlists = []
	  @my_cases = []
	end

	respond_to do |format|
	  format.html do
	    if params.has_key?(:is_ajax)
		  render :partial => "#{params[:is_ajax]}/#{params[:is_ajax]}_block"
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

  # post bookmark_item/:type
  # post bookmark_item/item_playlist
  # post bookmark_item/item_collage
  # this method calls the existing item_* forms to hook up to item_base_controllers new method
  # and then redirects to the users bookmark
  def bookmark_item
    if current_user.bookmark_id.nil?
	  playlist = Playlist.new({ :name => "Your Bookmarks", :title => "Your Bookmarks", :public => false })
	  playlist.save
      playlist.accepts_role!(:owner, current_user)
      playlist.accepts_role!(:creator, current_user)
	  current_user.update_attribute(:bookmark_id, playlist.id)
	end

    params[:container_id] = current_user.bookmark_id
	klass = params[:type].classify.constantize
    @object = klass.new(:url => params[:url])
	@base_model_class = params[:type] == 'item_default' ? nil : klass.to_s.gsub(/Item|Controller/, '').singularize.constantize

    respond_to do |format|
      format.html { render :partial => "/shared/forms/#{params[:type]}" }
    end
  end
end
