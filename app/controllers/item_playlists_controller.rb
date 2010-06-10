class ItemPlaylistsController < ApplicationController
  # GET /item_playlists
  # GET /item_playlists.xml
  def index
    @item_playlists = ItemPlaylist.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item_playlists }
    end
  end

  # GET /item_playlists/1
  # GET /item_playlists/1.xml
  def show
    @item_playlist = ItemPlaylist.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item_playlist }
    end
  end

  # GET /item_playlists/new
  # GET /item_playlists/new.xml
  def new
    @item_playlist = ItemPlaylist.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @item_playlist }
    end
  end

  # GET /item_playlists/1/edit
  def edit
    @item_playlist = ItemPlaylist.find(params[:id])
  end

  # POST /item_playlists
  # POST /item_playlists.xml
  def create
    @item_playlist = ItemPlaylist.new(params[:item_playlist])

    respond_to do |format|
      if @item_playlist.save
        flash[:notice] = 'ItemPlaylist was successfully created.'
        format.html { redirect_to(@item_playlist) }
        format.xml  { render :xml => @item_playlist, :status => :created, :location => @item_playlist }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item_playlist.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /item_playlists/1
  # PUT /item_playlists/1.xml
  def update
    @item_playlist = ItemPlaylist.find(params[:id])

    respond_to do |format|
      if @item_playlist.update_attributes(params[:item_playlist])
        flash[:notice] = 'ItemPlaylist was successfully updated.'
        format.html { redirect_to(@item_playlist) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item_playlist.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /item_playlists/1
  # DELETE /item_playlists/1.xml
  def destroy
    @item_playlist = ItemPlaylist.find(params[:id])
    @item_playlist.destroy

    respond_to do |format|
      format.html { redirect_to(item_playlists_url) }
      format.xml  { head :ok }
    end
  end
end
