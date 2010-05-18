class ExcerptsController < ApplicationController
  # GET /excerpts
  # GET /excerpts.xml
  def index
    @excerpts = Excerpt.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @excerpts }
    end
  end

  # GET /excerpts/1
  # GET /excerpts/1.xml
  def show
    @excerpt = Excerpt.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @excerpt }
    end
  end

  # GET /excerpts/new
  # GET /excerpts/new.xml
  def new
    @excerpt = Excerpt.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @excerpt }
    end
  end

  # GET /excerpts/1/edit
  def edit
    @excerpt = Excerpt.find(params[:id])
  end

  # POST /excerpts
  # POST /excerpts.xml
  def create
    @excerpt = Excerpt.new(params[:excerpt])

    respond_to do |format|
      if @excerpt.save
        flash[:notice] = 'Excerpt was successfully created.'
        format.html { redirect_to(@excerpt) }
        format.xml  { render :xml => @excerpt, :status => :created, :location => @excerpt }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @excerpt.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /excerpts/1
  # PUT /excerpts/1.xml
  def update
    @excerpt = Excerpt.find(params[:id])

    respond_to do |format|
      if @excerpt.update_attributes(params[:excerpt])
        flash[:notice] = 'Excerpt was successfully updated.'
        format.html { redirect_to(@excerpt) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @excerpt.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /excerpts/1
  # DELETE /excerpts/1.xml
  def destroy
    @excerpt = Excerpt.find(params[:id])
    @excerpt.destroy

    respond_to do |format|
      format.html { redirect_to(excerpts_url) }
      format.xml  { head :ok }
    end
  end
end
