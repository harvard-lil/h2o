class CasesController < BaseController

  before_filter :prep_resources
  before_filter :require_user, :except => [:index, :show, :metadata]
  before_filter :load_case, :only => [:show, :edit, :update, :destroy]

  # Only admin can edit cases - they must remain pretty much immutable, otherwise annotations could get
  # messed up in terms of location.

  access_control do
    allow :admin
    allow all, :to => [:show, :index, :new, :create, :metadata]
  end

  def metadata
    #FIXME
  end

  # GET /cases
  # GET /cases.xml
  def index
    @cases = Case.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @cases }
    end
  end

  # GET /cases/1
  # GET /cases/1.xml
  def show
    @case = Case.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @case }
    end
  end

  # GET /cases/new
  # GET /cases/new.xml
  def new
    @case = Case.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @case }
    end
  end

  # GET /cases/1/edit
  def edit
    @case = Case.find(params[:id])
  end

  # POST /cases
  # POST /cases.xml
  def create
    @case = Case.new(params[:case])

    respond_to do |format|
      if @case.save
        flash[:notice] = 'Case was successfully created.'
        format.html { redirect_to(@case) }
        format.xml  { render :xml => @case, :status => :created, :location => @case }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @case.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /cases/1
  # PUT /cases/1.xml
  def update
    @case = Case.find(params[:id])

    respond_to do |format|
      if @case.update_attributes(params[:case])
        flash[:notice] = 'Case was successfully updated.'
        format.html { redirect_to(@case) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @case.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /cases/1
  # DELETE /cases/1.xml
  def destroy
    @case = Case.find(params[:id])
    @case.destroy

    respond_to do |format|
      format.html { redirect_to(cases_url) }
      format.xml  { head :ok }
    end
  end

  private 

  def prep_resources
    add_javascripts ['jquery.tablesorter.min','cases']
    add_stylesheets ['tablesorter-h2o-theme/style','cases']
  end

  def load_case
    @case = Case.find((params[:id].blank?) ? params[:case_id] : params[:id])
  end

end
