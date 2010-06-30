class CaseJurisdictionsController < BaseController

  before_filter :require_user, :except => [:index, :show]
  
  access_control do
    allow :case_manager
    allow :admin
    allow all, :to => [:show, :index]
  end

  # GET /case_jurisdictions
  # GET /case_jurisdictions.xml
  def index
    @case_jurisdictions = CaseJurisdiction.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @case_jurisdictions }
    end
  end

  # GET /case_jurisdictions/1
  # GET /case_jurisdictions/1.xml
  def show
    @case_jurisdiction = CaseJurisdiction.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @case_jurisdiction }
    end
  end

  # GET /case_jurisdictions/new
  # GET /case_jurisdictions/new.xml
  def new
    @case_jurisdiction = CaseJurisdiction.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @case_jurisdiction }
    end
  end

  # GET /case_jurisdictions/1/edit
  def edit
    @case_jurisdiction = CaseJurisdiction.find(params[:id])
  end

  # POST /case_jurisdictions
  # POST /case_jurisdictions.xml
  def create
    @case_jurisdiction = CaseJurisdiction.new(params[:case_jurisdiction])

    respond_to do |format|
      if @case_jurisdiction.save
        flash[:notice] = 'CaseJurisdiction was successfully created.'
        format.html { redirect_to(@case_jurisdiction) }
        format.xml  { render :xml => @case_jurisdiction, :status => :created, :location => @case_jurisdiction }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @case_jurisdiction.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /case_jurisdictions/1
  # PUT /case_jurisdictions/1.xml
  def update
    @case_jurisdiction = CaseJurisdiction.find(params[:id])

    respond_to do |format|
      if @case_jurisdiction.update_attributes(params[:case_jurisdiction])
        flash[:notice] = 'CaseJurisdiction was successfully updated.'
        format.html { redirect_to(@case_jurisdiction) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @case_jurisdiction.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /case_jurisdictions/1
  # DELETE /case_jurisdictions/1.xml
  def destroy
    @case_jurisdiction = CaseJurisdiction.find(params[:id])
    @case_jurisdiction.destroy

    respond_to do |format|
      format.html { redirect_to(case_jurisdictions_url) }
      format.xml  { head :ok }
    end
  end
end
