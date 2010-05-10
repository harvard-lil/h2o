class CasebooksController < ApplicationController
  def annotation

  end

  # GET /casebooks
  # GET /casebooks.xml
  def index
    @casebooks = Casebook.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @casebooks }
    end
  end

  # GET /casebooks/1
  # GET /casebooks/1.xml
  def show
    @casebook = Casebook.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @casebook }
    end
  end

  # GET /casebooks/new
  # GET /casebooks/new.xml
  def new
    @casebook = Casebook.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @casebook }
    end
  end

  # GET /casebooks/1/edit
  def edit
    @casebook = Casebook.find(params[:id])
  end

  # POST /casebooks
  # POST /casebooks.xml
  def create
    @casebook = Casebook.new(params[:casebook])

    respond_to do |format|
      if @casebook.save
        flash[:notice] = 'Casebook was successfully created.'
        format.html { redirect_to(@casebook) }
        format.xml  { render :xml => @casebook, :status => :created, :location => @casebook }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @casebook.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /casebooks/1
  # PUT /casebooks/1.xml
  def update
    @casebook = Casebook.find(params[:id])

    respond_to do |format|
      if @casebook.update_attributes(params[:casebook])
        flash[:notice] = 'Casebook was successfully updated.'
        format.html { redirect_to(@casebook) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @casebook.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /casebooks/1
  # DELETE /casebooks/1.xml
  def destroy
    @casebook = Casebook.find(params[:id])
    @casebook.destroy

    respond_to do |format|
      format.html { redirect_to(casebooks_url) }
      format.xml  { head :ok }
    end
  end
end
