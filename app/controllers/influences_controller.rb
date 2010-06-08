class InfluencesController < ApplicationController
  # GET /influences
  # GET /influences.xml
  def index
    @influences = Influence.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @influences }
    end
  end

  # GET /influences/1
  # GET /influences/1.xml
  def show
    @influence = Influence.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @influence }
    end
  end

  # GET /influences/new
  # GET /influences/new.xml
  def new
    @influence = Influence.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @influence }
    end
  end

  # GET /influences/1/edit
  def edit
    @influence = Influence.find(params[:id])
  end

  # POST /influences
  # POST /influences.xml
  def create
    @influence = Influence.new(params[:influence])

    respond_to do |format|
      if @influence.save
        flash[:notice] = 'Influence was successfully created.'
        format.html { redirect_to(@influence) }
        format.xml  { render :xml => @influence, :status => :created, :location => @influence }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @influence.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /influences/1
  # PUT /influences/1.xml
  def update
    @influence = Influence.find(params[:id])

    respond_to do |format|
      if @influence.update_attributes(params[:influence])
        flash[:notice] = 'Influence was successfully updated.'
        format.html { redirect_to(@influence) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @influence.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /influences/1
  # DELETE /influences/1.xml
  def destroy
    @influence = Influence.find(params[:id])
    @influence.destroy

    respond_to do |format|
      format.html { redirect_to(influences_url) }
      format.xml  { head :ok }
    end
  end
end
