class ItemRotisserieDiscussionsController < ApplicationController
  # GET /item_rotisserie_discussions
  # GET /item_rotisserie_discussions.xml
  def index
    @item_rotisserie_discussions = ItemRotisserieDiscussion.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item_rotisserie_discussions }
    end
  end

  # GET /item_rotisserie_discussions/1
  # GET /item_rotisserie_discussions/1.xml
  def show
    @item_rotisserie_discussion = ItemRotisserieDiscussion.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item_rotisserie_discussion }
    end
  end

  # GET /item_rotisserie_discussions/new
  # GET /item_rotisserie_discussions/new.xml
  def new
    @item_rotisserie_discussion = ItemRotisserieDiscussion.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @item_rotisserie_discussion }
    end
  end

  # GET /item_rotisserie_discussions/1/edit
  def edit
    @item_rotisserie_discussion = ItemRotisserieDiscussion.find(params[:id])
  end

  # POST /item_rotisserie_discussions
  # POST /item_rotisserie_discussions.xml
  def create
    @item_rotisserie_discussion = ItemRotisserieDiscussion.new(params[:item_rotisserie_discussion])

    container_id = params[:container_id]

    respond_to do |format|
      if @item_rotisserie_discussion.save
        @item_rotisserie_discussion.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist_id => container_id)
        playlist_item.resource_item = @item_rotisserie_discussion

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'ItemDefault was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@item_rotisserie_discussion) }
        format.xml  { render :xml => @item_rotisserie_discussion, :status => :created, :location => @item_rotisserie_discussion }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item_rotisserie_discussion.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /item_rotisserie_discussions/1
  # PUT /item_rotisserie_discussions/1.xml
  def update
    @item_rotisserie_discussion = ItemRotisserieDiscussion.find(params[:id])

    respond_to do |format|
      if @item_rotisserie_discussion.update_attributes(params[:item_rotisserie_discussion])
        flash[:notice] = 'ItemRotisserieDiscussion was successfully updated.'
        format.html { redirect_to(@item_rotisserie_discussion) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item_rotisserie_discussion.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /item_rotisserie_discussions/1
  # DELETE /item_rotisserie_discussions/1.xml
  def destroy
    @item_rotisserie_discussion = ItemRotisserieDiscussion.find(params[:id])
    @item_rotisserie_discussion.destroy

    respond_to do |format|
      format.html { redirect_to(item_rotisserie_discussions_url) }
      format.xml  { head :ok }
    end
  end
end
