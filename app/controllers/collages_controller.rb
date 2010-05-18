class CollagesController < ApplicationController

  before_filter :prep_resources

  # GET /collages
  # GET /collages.xml
  def index
    @collages = Collage.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @collages }
    end
  end

  # GET /collages/1
  # GET /collages/1.xml
  def show
    @collage = Collage.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @collage }
    end
  end

  # GET /collages/new
  # GET /collages/new.xml
  def new
    @collage = Collage.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @collage }
    end
  end

  # GET /collages/1/edit
  def edit
    @collage = Collage.find(params[:id])
  end

  # POST /collages
  # POST /collages.xml
  def create
    @collage = Collage.new(params[:collage])

    respond_to do |format|
      if @collage.save
        flash[:notice] = 'Collage was successfully created.'
        format.html { redirect_to(@collage) }
        format.xml  { render :xml => @collage, :status => :created, :location => @collage }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @collage.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /collages/1
  # PUT /collages/1.xml
  def update
    @collage = Collage.find(params[:id])

    respond_to do |format|
      if @collage.update_attributes(params[:collage])
        flash[:notice] = 'Collage was successfully updated.'
        format.html { redirect_to(@collage) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @collage.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /collages/1
  # DELETE /collages/1.xml
  def destroy
    @collage = Collage.find(params[:id])
    @collage.destroy

    respond_to do |format|
      format.html { redirect_to(collages_url) }
      format.xml  { head :ok }
    end
  end

  private 

  def prep_resources
    add_javascripts 'collages'
    add_stylesheets 'collages'
  end


end
