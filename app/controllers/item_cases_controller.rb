class ItemCasesController < ApplicationController

  # POST /item_cases
  # POST /item_cases.xml
  def create
    @item_case = ItemCase.new(params[:item_case])

    container_id = params[:container_id]

    respond_to do |format|
      if @item_case.save
        @item_case.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist_id => container_id)
        playlist_item.resource_item = @item_case

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'ItemDefault was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@item_case) }
        format.xml  { render :xml => @item_case, :status => :created, :location => @item_case }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item_case.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /item_cases/1
  # PUT /item_cases/1.xml
  def update
    @item_case = ItemCase.find(params[:id])

    respond_to do |format|
      if @item_case.update_attributes(params[:item_case])
        flash[:notice] = 'ItemCase was successfully updated.'
        format.html { redirect_to(@item_case) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item_case.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /item_cases/1
  # DELETE /item_cases/1.xml
  def destroy
    @item_case = ItemCase.find(params[:id])
    @item_case.destroy

    respond_to do |format|
      format.html { redirect_to(item_cases_url) }
      format.xml  { head :ok }
    end
  end

end
