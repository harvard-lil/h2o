class ItemCollagesController < ApplicationController
  # POST /item_collages
  # POST /item_collages.xml
  def create
    @item_collage = ItemCollage.new(params[:item_collage])

    container_id = params[:container_id]

    respond_to do |format|
      if @item_collage.save
        @item_collage.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist_id => container_id)
        playlist_item.resource_item = @item_collage

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'We successfully created that collage playlist item.'
        format.js {render :text => nil}
        format.html { redirect_to(@item_collage) }
        format.xml  { render :xml => @item_collage, :status => :created, :location => @item_collage }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item_collage.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /item_collages/1
  # PUT /item_collages/1.xml
  def update
    @item_collage = ItemCollage.find(params[:id])

    respond_to do |format|
      if @item_collage.update_attributes(params[:item_collage])
        flash[:notice] = 'ItemCollage was successfully updated.'
        format.html { redirect_to(@item_collage) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item_collage.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /item_collages/1
  # DELETE /item_collages/1.xml
  def destroy
    @item_collage = ItemCollage.find(params[:id])
    @item_collage.destroy

    respond_to do |format|
      format.html { redirect_to(item_collages_url) }
      format.xml  { head :ok }
    end
  end

end
