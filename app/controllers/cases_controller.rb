class CasesController < BaseController

  before_filter :prep_resources
  before_filter :require_user, :except => [:index, :show, :metadata]
  before_filter :load_case, :only => [:show, :edit, :update, :destroy]

  # Only admin can edit cases - they must remain pretty much immutable, otherwise annotations could get
  # messed up in terms of location.

  access_control do
    allow :case_manager
    allow :admin
    allow :owner, :of => :case, :to => [:destroy, :edit, :update]
    allow all, :to => [:show, :index, :metadata, :autocomplete_tags, :new, :create]
  end

  def autocomplete_tags
    render :json => Case.autocomplete_for(:tags,params[:tag])
  end

  def metadata
    #FIXME
  end

  # GET /cases
  # GET /cases.xml
  def index
    if params[:tags]
      @cases = Case.tagged_with(params[:tags], :any => (params[:any] ? true : false)).paginate(:include => [:tags, :collages, :case_citations], :page => params[:page], :per_page => cookies[:per_page] || nil, :order => 'short_name')
    else
      @cases = Case.paginate(:include => [:tags, :collages, :case_citations], :page => params[:page], :per_page => cookies[:per_page] || nil, :order => 'short_name')
    end
    @tags = Case.tag_counts_on(:tags).all(:order => :name)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @cases }
    end
  end

  # GET /cases/1
  # GET /cases/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @case }
    end
  end

  # GET /cases/new
  # GET /cases/new.xml
  def new
    @case = Case.new
    @case.case_jurisdiction = CaseJurisdiction.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @case }
    end
  end

  # GET /cases/1/edit
  def edit
  end

  # POST /cases
  # POST /cases.xml
  def create
    unless params[:case][:tag_list].blank?
      params[:case][:tag_list] = params[:case][:tag_list].downcase
    end
    @case = Case.new(params[:case])
    @case.accepts_role!(:owner, current_user)
    @case.accepts_role!(:creator, current_user)

    respond_to do |format|
      if @case.save
        flash[:notice] = 'Case was successfully created.'
        format.html { redirect_to(cases_url) }
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
    unless params[:case][:tag_list].blank?
      params[:case][:tag_list] = params[:case][:tag_list].downcase
    end
    respond_to do |format|
      if @case.update_attributes(params[:case])
        flash[:notice] = 'Case was successfully updated.'
        format.html { redirect_to(cases_url) }
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
