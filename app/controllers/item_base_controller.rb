class ItemBaseController < BaseController

  cache_sweeper :item_base_sweeper

  before_filter :set_model
  before_filter :load_object_and_playlist, :except => [:new, :create]
  before_filter :create_object_and_load_playlist, :only => [:new, :create]
  before_filter :require_user, :except => [:index, :show]

  access_control do
    allow all, :to => [:show, :index]

    allow logged_in, :to => [:edit, :update], :if => :allow_update?
    allow :admin, :playlist_admin, :superadmin
    allow :owner, :of => :playlist
    allow :editor, :of => :playlist, :to => [:edit, :update]
  end

  def allow_update?
    load_object_and_playlist

    current_user.can_permission_playlist("edit_notes", @playlist) || 
      current_user.can_permission_playlist("edit_descriptions", @playlist)
  end

  def index
    @objects = @model_class.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item_defaults }
    end
  end

  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item_default }
    end
  end

  def new
    @object.url = params[:url_string]
    if @model_class == ItemCollage
      collage_id = @object.url.match(/[0-9]+$/).to_s
      actual_item = Collage.find(collage_id)
      @object.name = actual_item.name
      @object.description = actual_item.description
    end
    
    respond_to do |format|
      format.html { render :partial => "shared/forms/playlist_item" }
      format.xml  { render :xml => @item_default }
    end
  end

  def create
    # Note: Exception is always getting triggered here, on create, because item doesn't exist ever
    #if controller_class_name == "ItemDefaultsController"
    #  begin
    #    id = params[:item_default][:url].match(/[0-9]+$/)[0]
    #    item = ItemDefault.find(id)
    #    params[:item_default][:url] = item.url
    #  rescue Exception => e
    #    logger.warn('Unable to update default item url:' + e.inspect)
    #  end
    #end

    @object.update_attributes(params[@param_symbol])

    @base_object = nil
    logger.warn('Base model class' + @base_model_class.inspect)

    if @base_model_class
      begin
        #We believe we have found an object we can link directly to in this instance. Let's see!
        uri = URI.parse(params[@param_symbol][:url])
        recognized_item = ActionController::Routing::Routes.recognize_path(uri.path, :method => :get)
        @base_object = @base_model_class.find(recognized_item[:id])

        logger.warn('URL manually passed in:' + params[@param_symbol][:url])
        logger.warn('URL we guessed:' + url_for(@base_object))

        #FIXME: This might break if an h2o instances is hosted under a directory.
        if params[@param_symbol][:url] == url_for(@base_object)
          #This looks like it's a local object we can link directly to.
          @object.actual_object = @base_object
        else
          # Not local. Do nothing.

        end
        rescue Exception => e
          logger.warn('oopsy.' + e.inspect)
        end
    end

    respond_to do |format|
      if @object.save
        @object.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist => @playlist)
        playlist_item.resource_item = @object

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        format.js {render :text => nil}
        format.html { redirect_to(@object) }
        format.xml { render :xml => @object, :status => :created, :location => @object }
	      format.json { render :json => { :type => 'playlists', :id => @playlist.id, :error => false } }
      else
        format.js {
          render :text => "We couldn't add that playlist item. Sorry!<br/>#{@object.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity 
        }
        format.html { render :action => "new" }
        format.xml { render :xml => @object.errors, :status => :unprocessable_entity }
	      format.json { render :json => { :message => "We could not add that playlist item: #{@object.errors.full_messages.join('<br />')}", :error => true } }
      end
    end
  end

  def edit
    if current_user
      @can_edit_all = current_user.has_role?(:superadmin) ||
                      current_user.has_role?(:admin) || 
                      current_user.has_role?(:editor, @playlist) || 
                      current_user.has_role?(:owner, @playlist)
      @can_edit_notes = @can_edit_all || current_user.can_permission_playlist("edit_notes", @playlist)
      @can_edit_desc = @can_edit_all || current_user.can_permission_playlist("edit_descriptions", @playlist)
    else
      @can_edit_all = @can_edit_notes = @can_edit_desc = false
    end

    render :partial => "shared/forms/playlist_item"
  end


  def update
    if current_user
      can_edit_all = current_user.has_role?(:superadmin) ||
                      current_user.has_role?(:admin) || 
                      current_user.has_role?(:editor, @playlist) || 
                      current_user.has_role?(:owner, @playlist)
      can_edit_notes = can_edit_all || current_user.can_permission_playlist("edit_notes", @playlist)
      can_edit_desc = can_edit_all || current_user.can_permission_playlist("edit_descriptions", @playlist)
    else
      can_edit_all = can_edit_notes = can_edit_desc = false
    end

    if !can_edit_desc 
      params["item_playlist"].delete("description")
    end
    if !can_edit_notes
      params.delete("playlist_item")
    else
      params[:playlist_item][:public_notes] = params[:playlist_item][:public_notes] == 'on' ? true : false
    end

    if @object.update_attributes(params[@param_symbol]) && @object.playlist_item.update_attributes(params[:playlist_item])
	    render :json => { :type => 'playlists', :id => @playlist.id }
    else
	    render :json => { :error => @object.errors }
    end
  end

  def destroy
    @object = @model_class.find(params[:id])
    @object.destroy

    respond_to do |format|
      format.js { render :text => nil }
      format.html { redirect_to(item_cases_url) }
      format.xml  { head :ok }
	  format.json { render :json => { :type => 'playlist_item', } }
    end
  end

  private
  
  def set_model
    @model_class = controller_class_name.gsub(/Controller/,'').singularize.constantize
    @base_model_class = nil

    begin
      @base_model_class = controller_class_name.gsub(/Item|Controller/,'').singularize.constantize
    rescue Exception => e
      logger.warn("We don't have a local type that's equivalent to that object: #{e.inspect}")
    end

    @param_symbol = @model_class.name.tableize.singularize.to_sym
  end

  def load_object_and_playlist
    @object = @model_class.find(params[:id])
    @playlist = @object.playlist_item.playlist
  end

  def create_object_and_load_playlist
    @object = @model_class.new
    @playlist = Playlist.find(params[:container_id])
  end

end
