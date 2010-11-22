class CasesController < BaseController

  before_filter :prep_resources
  before_filter :my_cases, :only => [:index, :show]
  before_filter :is_case_admin, :except => [:embedded_pager, :metadata]
  before_filter :require_user, :except => [:index, :show, :metadata, :embedded_pager]
  before_filter :load_case, :only => [:show, :edit, :update, :destroy]

  # Only admin can edit cases - they must remain pretty much immutable, otherwise annotations could get
  # messed up in terms of location.

  access_control do
    allow all, :to => [:show, :index, :metadata, :autocomplete_tags, :new, :create, :embedded_pager]
    allow :case_manager, :admin, :superadmin
    allow :owner, :of => :case, :to => [:destroy, :edit, :update]
  end

  def autocomplete_tags
    render :json => Case.autocomplete_for(:tags,params[:tag])
  end

  def metadata
    #FIXME
  end

  def embedded_pager
    super Case
  end

  # GET /cases
  # GET /cases.xml
  def index
    @cases = Sunspot.new_search(Case)

    @cases.build do
      unless params[:keywords].blank?
        keywords params[:keywords]
      end
      with :public, true
      with :active, true
      paginate :page => params[:page], :per_page => cookies[:per_page] || nil
      data_accessor_for(Case).include = [:tags, :collages, :case_citations]
      order_by :display_name, :asc
    end

    if params[:tags]

      if params[:any] 
        @cases.build do
          any_of do
            params[:tags].each do|t|
              with :tag_list, t
            end
          end
        end

      else
        @cases.build do
          params[:tags].each do|t|
            with :tag_list, t
          end
        end
      end

    end

    @cases.execute!

    respond_to do |format|
      format.html # index.html.erb
      format.js { render :partial => 'case_list' }
      format.xml  { render :xml => @cases }
    end
  end

  # GET /cases/1
  # GET /cases/1.xml
  def show
    if (! @case.public || ! @case.active ) && ! @my_cases.include?(@case)
      #if not public or active and the case isn't one of mine. . .
      render :status => :not_found 
    else
      respond_to do |format|
        format.html # show.html.erb
        format.xml  { render :xml => @case }
      end
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

    respond_to do |format|
      if @case.save
        @case.accepts_role!(:owner, current_user)
        @case.accepts_role!(:creator, current_user)
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
    add_javascripts ['jquery.tablesorter.min','markitup/jquery.markitup.js','markitup/sets/html/set.js','cases']
    add_stylesheets ['tablesorter-h2o-theme/style','/javascripts/markitup/skins/markitup/style.css','/javascripts/markitup/sets/html/style.css','cases']
  end

  def load_case
    @case = Case.find((params[:id].blank?) ? params[:case_id] : params[:id])
  end

    def is_case_admin
      if current_user
        @is_case_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','case_admin','superadmin']}).length > 0
      end
    end

    def my_cases
      if current_user
        @my_cases = current_user.cases
      end
    end

end
