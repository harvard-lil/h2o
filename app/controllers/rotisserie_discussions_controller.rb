class RotisserieDiscussionsController < ApplicationController
  # GET /rotisserie_discussions
  # GET /rotisserie_discussions.xml
  def index
    @rotisserie_discussions = RotisserieDiscussion.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @rotisserie_discussions }
    end
  end

  # GET /rotisserie_discussions/1
  # GET /rotisserie_discussions/1.xml
  def show
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @rotisserie_discussion }
    end
  end

  # GET /rotisserie_discussions/new
  # GET /rotisserie_discussions/new.xml
  def new
    @rotisserie_discussion = RotisserieDiscussion.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @rotisserie_discussion }
    end
  end

  # GET /rotisserie_discussions/1/edit
  def edit
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])
  end

  # POST /rotisserie_discussions
  # POST /rotisserie_discussions.xml
  def create
    @rotisserie_discussion = RotisserieDiscussion.new(params[:rotisserie_discussion])

    respond_to do |format|
      if @rotisserie_discussion.save
        flash[:notice] = 'RotisserieDiscussion was successfully created.'
        format.html { redirect_to(@rotisserie_discussion) }
        format.xml  { render :xml => @rotisserie_discussion, :status => :created, :location => @rotisserie_discussion }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @rotisserie_discussion.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /rotisserie_discussions/1
  # PUT /rotisserie_discussions/1.xml
  def update
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])

    respond_to do |format|
      if @rotisserie_discussion.update_attributes(params[:rotisserie_discussion])
        flash[:notice] = 'RotisserieDiscussion was successfully updated.'
        format.html { redirect_to(@rotisserie_discussion) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @rotisserie_discussion.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /rotisserie_discussions/1
  # DELETE /rotisserie_discussions/1.xml
  def destroy
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])
    @rotisserie_discussion.destroy

    respond_to do |format|
      format.html { redirect_to(rotisserie_discussions_url) }
      format.xml  { head :ok }
    end
  end
end
