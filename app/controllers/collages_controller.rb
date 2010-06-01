class CollagesController < ApplicationController

  before_filter :prep_resources
  before_filter :load_collage, :only => [:layers, :excerpts, :annotations, :show, :edit, :update, :destroy, :undo_excerpt, :undo_annotation]  

  def undo_excerpt
    excerpt = @collage.excerpts.last
    excerpt.destroy
    flash[:notice] = "We've removed that excerpt."
    redirect_to @collage
  rescue Exception => e
    render :text => "Sorry, we couldn't remove that excerpt.", :status => :unprocessable_entity
  end

  def undo_annotation
    annotation = @collage.annotations.last
    annotation.destroy
    flash[:notice] = "We've removed that annotation."
    redirect_to @collage
  rescue Exception => e
    render :text => "Sorry, we couldn't remove that annotation", :status => :unprocessable_entity
  end

  def layers
    respond_to do |format|
      format.json { render :json => @collage.layers }
    end
  end

  def excerpts
    respond_to do |format|
      format.json { render :json => @collage.excerpts }
    end
  end

  def annotations
    respond_to do |format|
      format.json { render :json => @collage.annotations.to_json(:include => [:layers]) }
    end
  end

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

  def load_collage
    @collage = Collage.find((params[:id].blank?) ? params[:collage_id] : params[:id])
  end

end
