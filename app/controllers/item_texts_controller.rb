class ItemTextsController < ApplicationController
  # GET /item_texts
  # GET /item_texts.xml
  def index
    @item_texts = ItemText.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item_texts }
    end
  end

  # GET /item_texts/1
  # GET /item_texts/1.xml
  def show
    @item_text = ItemText.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item_text }
    end
  end

  # GET /item_texts/new
  # GET /item_texts/new.xml
  def new
    @item_text = ItemText.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @item_text }
    end
  end

  # GET /item_texts/1/edit
  def edit
    @item_text = ItemText.find(params[:id])
  end

  # POST /item_texts
  # POST /item_texts.xml
  def create
    @item_text = ItemText.new(params[:item_text])
    container_id = params[:container_id]

    respond_to do |format|
      if @item_text.save
        @item_text.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist_id => container_id)
        playlist_item.resource_item = @item_text

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'ItemText was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@item_text) }
        format.xml  { render :xml => @item_text, :status => :created, :location => @item_text }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item_text.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /item_texts/1
  # PUT /item_texts/1.xml
  def update
    @item_text = ItemText.find(params[:id])

    respond_to do |format|
      if @item_text.update_attributes(params[:item_text])
        flash[:notice] = 'ItemText was successfully updated.'
        format.html { redirect_to(@item_text) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item_text.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /item_texts/1
  # DELETE /item_texts/1.xml
  def destroy
    @item_text = ItemText.find(params[:id])
    @item_text.destroy

    respond_to do |format|
      format.html { redirect_to(item_texts_url) }
      format.xml  { head :ok }
    end
  end
end
