class ItemDefaultsController < ApplicationController
  # GET /item_defaults
  # GET /item_defaults.xml
  def index
    @item_defaults = ItemDefault.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item_defaults }
    end
  end

  # GET /item_defaults/1
  # GET /item_defaults/1.xml
  def show
    @item_default = ItemDefault.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item_default }
    end
  end

  # GET /item_defaults/new
  # GET /item_defaults/new.xml
  def new
    @item_default = ItemDefault.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @item_default }
    end
  end

  # GET /item_defaults/1/edit
  def edit
    @item_default = ItemDefault.find(params[:id])
  end

  # POST /item_defaults
  # POST /item_defaults.xml
  def create
    @item_default = ItemDefault.new(params[:item_default])
    container_id = params[:container_id]

    respond_to do |format|
      if @item_default.save
        @item_default.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist_id => container_id)
        playlist_item.resource_item = @item_default
        
        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'ItemDefault was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@item_default) }
        format.xml  { render :xml => @item_default, :status => :created, :location => @item_default }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item_default.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /item_defaults/1
  # PUT /item_defaults/1.xml
  def update
    @item_default = ItemDefault.find(params[:id])

    respond_to do |format|
      if @item_default.update_attributes(params[:item_default])
        flash[:notice] = 'ItemDefault was successfully updated.'
        format.html { redirect_to(@item_default) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item_default.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /item_defaults/1
  # DELETE /item_defaults/1.xml
  def destroy
    @item_default = ItemDefault.find(params[:id])
    @item_default.destroy

    respond_to do |format|
      format.html { redirect_to(item_defaults_url) }
      format.xml  { head :ok }
    end
  end
end
