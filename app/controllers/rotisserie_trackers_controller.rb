class RotisserieTrackersController < ApplicationController
  # GET /rotisserie_trackers
  # GET /rotisserie_trackers.xml
  def index
    @rotisserie_trackers = RotisserieTracker.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @rotisserie_trackers }
    end
  end

  # GET /rotisserie_trackers/1
  # GET /rotisserie_trackers/1.xml
  def show
    @rotisserie_tracker = RotisserieTracker.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @rotisserie_tracker }
    end
  end

  # GET /rotisserie_trackers/new
  # GET /rotisserie_trackers/new.xml
  def new
    @rotisserie_tracker = RotisserieTracker.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @rotisserie_tracker }
    end
  end

  # GET /rotisserie_trackers/1/edit
  def edit
    @rotisserie_tracker = RotisserieTracker.find(params[:id])
  end

  # POST /rotisserie_trackers
  # POST /rotisserie_trackers.xml
  def create
    @rotisserie_tracker = RotisserieTracker.new(params[:rotisserie_tracker])

    respond_to do |format|
      if @rotisserie_tracker.save
        flash[:notice] = 'RotisserieTracker was successfully created.'
        format.html { redirect_to(@rotisserie_tracker) }
        format.xml  { render :xml => @rotisserie_tracker, :status => :created, :location => @rotisserie_tracker }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @rotisserie_tracker.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /rotisserie_trackers/1
  # PUT /rotisserie_trackers/1.xml
  def update
    @rotisserie_tracker = RotisserieTracker.find(params[:id])

    respond_to do |format|
      if @rotisserie_tracker.update_attributes(params[:rotisserie_tracker])
        flash[:notice] = 'RotisserieTracker was successfully updated.'
        format.html { redirect_to(@rotisserie_tracker) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @rotisserie_tracker.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /rotisserie_trackers/1
  # DELETE /rotisserie_trackers/1.xml
  def destroy
    @rotisserie_tracker = RotisserieTracker.find(params[:id])
    @rotisserie_tracker.destroy

    respond_to do |format|
      format.html { redirect_to(rotisserie_trackers_url) }
      format.xml  { head :ok }
    end
  end
end
