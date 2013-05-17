class PlaylistItemsController < BaseController
  
  before_filter :load_playlist
  #TODO - Get playlist delegation and editing working properly.

  access_control do
    allow all, :to => [:show]
    allow logged_in, :to => [:new, :create]

    allow :admin, :playlist_admin, :superadmin
    allow :owner, :of => :playlist
    allow :editor, :of => :playlist, :to => [:edit, :update]
  end
  
  def show
    playlist_item = PlaylistItem.find(params[:id])
    render :partial => 'shared/objects/playlist_item',
      :locals => { :item => playlist_item,
      :resource_item => playlist_item.resource_item,
      :actual_object => playlist_item.resource_item.actual_object,
      :parent_index => '', 
      :index => params[:playlist_index],
      :recursive_level => 0,
      :last => false }
  end

  def new
    @playlist_item = PlaylistItem.new(:playlist_id => params[:container_id])

    respond_to do |format|
      format.js
      format.html # new.html.erb
      format.xml  { render :xml => @playlist_item }
    end
  end

  def edit
    @playlist_item = PlaylistItem.find(params[:id])
  end

  def create
    @playlist_item = PlaylistItem.new(params[:playlist_item])
    
    respond_to do |format|
      if @playlist_item.save
        
        flash[:notice] = 'PlaylistItem was successfully created.'
        format.html { redirect_to(@playlist_item) }
        format.xml  { render :xml => @playlist_item, :status => :created, :location => @playlist_item }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @playlist_item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    @playlist_item = PlaylistItem.find(params[:id])

    respond_to do |format|
      if @playlist_item.update_attributes(params[:playlist_item])
        flash[:notice] = 'PlaylistItem was successfully updated.'
        format.html { redirect_to(@playlist_item) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @playlist_item.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def destroy
    @playlist_item = PlaylistItem.find(params[:id])
    @playlist_item.destroy

    respond_to do |format|
      format.html { redirect_to(playlist_items_url) }
      format.xml  { head :ok }
    end
  end

  # Used in the ajax stuff to emit a representation of this individual item.
  def block
    @playlist = Playlist.find(params[:container_id] || params[:playlist_id])

    respond_to do |format|
      format.html {
        render :partial => 'playlist_items_block',
        :locals => {:playlist => @playlist},
        :layout => false
      }
      format.xml  { head :ok }
    end
  end

  def load_playlist
    if params[:playlist_id] || params[:container_id]
      @playlist = Playlist.find(params[:playlist_id] || params[:container_id])
    end
    @my_playlist = (current_user) ? current_user.playlists.include?(@playlist) : false
  end

end
