class ItemYoutubesController < ApplicationController
  # GET /item_youtubes
  # GET /item_youtubes.xml
  def index
    @item_youtubes = ItemYoutube.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item_youtubes }
    end
  end

  # GET /item_youtubes/1
  # GET /item_youtubes/1.xml
  def show
    @item_youtube = ItemYoutube.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item_youtube }
    end
  end

  # GET /item_youtubes/new
  # GET /item_youtubes/new.xml
  def new
    @item_youtube = ItemYoutube.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @item_youtube }
    end
  end

  # GET /item_youtubes/1/edit
  def edit
    @item_youtube = ItemYoutube.find(params[:id])
  end

  # POST /item_youtubes
  # POST /item_youtubes.xml
  def create
    @item_youtube = ItemYoutube.new(params[:item_youtube])
    container_id = params[:container_id]

    respond_to do |format|
      if @item_youtube.save
        @item_youtube.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist_id => container_id)
        playlist_item.resource_item = @item_youtube

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'ItemYoutube was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@item_youtube) }
        format.xml  { render :xml => @item_youtube, :status => :created, :location => @item_youtube }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item_youtube.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /item_youtubes/1
  # PUT /item_youtubes/1.xml
  def update
    @item_youtube = ItemYoutube.find(params[:id])

    respond_to do |format|
      if @item_youtube.update_attributes(params[:item_youtube])
        flash[:notice] = 'ItemYoutube was successfully updated.'
        format.html { redirect_to(@item_youtube) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item_youtube.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /item_youtubes/1
  # DELETE /item_youtubes/1.xml
  def destroy
    @item_youtube = ItemYoutube.find(params[:id])
    @item_youtube.destroy

    respond_to do |format|
      format.html { redirect_to(item_youtubes_url) }
      format.xml  { head :ok }
    end
  end
end
