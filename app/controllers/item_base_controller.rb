class ItemBaseController < BaseController

  cache_sweeper :item_base_sweeper

  before_filter :set_model
  before_filter :load_object_and_playlist, :except => [:new, :create, :add_link_to_playlist, :embedded_pager]
  before_filter :create_object_and_load_playlist, :only => [:new, :create]
  before_filter :require_user, :except => [:index, :show]

  access_control do
    allow all, :to => [:show, :index]

    allow logged_in, :to => [:edit, :update], :if => :allow_update?
    allow :admin, :playlist_admin, :superadmin
    allow :owner, :of => :playlist
  end

  def allow_update?
    load_object_and_playlist

    current_user.can_permission_playlist("edit_notes", @playlist) || 
      current_user.can_permission_playlist("edit_descriptions", @playlist)
  end

  def index
    @objects = @model_class.all
  end

  def show
  end

  def new
    @can_edit_all = @can_edit_desc = true
    @can_edit_notes = false

    @object.url = params[:url_string]
    if [ItemCollage, ItemDefault].include?(@model_class)
      item_id = @object.url.match(/[0-9]+$/).to_s
      actual_item = @base_model_class.find(item_id)
      @url_display = actual_item.url if @base_model_class == Default
      @object.name = actual_item.name
      @object.description = actual_item.description
    end
    
    render :partial => "shared/forms/playlist_item"
  end

  def create
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
        end

        rescue Exception => e
          logger.warn('Failed to set actual object: ' + e.inspect)
        end
    end

    if @object.save
      @object.accepts_role!(:owner, current_user)

      playlist_item = PlaylistItem.new(:playlist => @playlist)
      playlist_item.resource_item = @object

      position_data = {}
      if playlist_item.save!
        position_data[playlist_item.id.to_s] = params[:position].to_i

        playlist_item.update_attribute(:position, params[:position].to_i)
        @playlist.playlist_items.each_with_index do |pi, index|
          if pi != playlist_item && (index + 1) >= params[:position].to_i
            position_data[pi.id] = (pi.position + 1).to_s
            pi.update_attribute(:position, pi.position + 1)
          end
        end
        playlist_item.accepts_role!(:owner, current_user)
      end

	    render :json => { :type => 'playlists', :playlist_item_id => playlist_item.id, :id => @playlist.id, :error => false, :position_data => position_data }
    else
	    render :json => { :message => "We could not add that playlist item: #{@object.errors.full_messages.join('<br />')}", :error => true }
    end
  end

  def edit
    if current_user
      @can_edit_all = current_user.has_role?(:superadmin) ||
                      current_user.has_role?(:admin) || 
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
	    render :json => { :type => 'playlists', :item => @object.to_json(:only => [:id, :name, :description]) }
    else
	    render :json => { :error => @object.errors }
    end
  end

  def destroy
    @model_class.find(params[:id]).destroy
    @playlist.reset_positions

	  render :json => { :type => 'playlist_item', :position_data => @playlist.playlist_items.inject({}) { |h, i| h[i.id] = i.position.to_s; h } }
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
