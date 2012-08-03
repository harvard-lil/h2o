class CasesController < BaseController

  cache_sweeper :case_sweeper

  before_filter :my_cases, :only => [:index, :show]
  before_filter :is_case_admin, :except => [:embedded_pager, :metadata]
  before_filter :require_user, :except => [:index, :show, :metadata, :embedded_pager, :export]
  before_filter :load_case, :only => [:show, :edit, :update, :destroy, :export]
  before_filter :store_location, :only => [:index, :show]

  # Only admin can edit cases - they must remain pretty much immutable, otherwise annotations could get
  # messed up in terms of location.

  access_control do
    allow all, :to => [:show, :index, :metadata, :autocomplete_tags, :new, :create, :embedded_pager, :export]
    allow :case_admin, :admin, :superadmin
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

  def build_search(params)
    cases = Sunspot.new_search(Case)
    
    cases.build do
      if params.has_key?(:keywords)
        keywords params[:keywords]
      end
      if params[:tags]
        if params[:any]
          any_of do
            params[:tags].each { |t| with :tag_list, t }
          end
        else
          params[:tags].each { |t| with :tag_list, t }
        end
      end
      if params[:tag]
        with :tag_list, CGI.unescape(params[:tag])
      end
      with :public, true
      with :active, true
      paginate :page => params[:page], :per_page => 25

      order_by params[:sort].to_sym, params[:order].to_sym
    end
    cases.execute!
    cases
  end

  # GET /cases
  # GET /cases.xml
  def index
    params[:page] ||= 1

    if params[:keywords]
      cases = build_search(params)
      t = cases.hits.inject([]) { |arr, h| arr.push(h.result); arr }
      @cases = WillPaginate::Collection.create(params[:page], 25, cases.total) { |pager| pager.replace(t) }
    else
      @cases = Rails.cache.fetch("cases-search-#{params[:page]}-#{params[:tag]}-#{params[:sort]}-#{params[:order]}") do 
        cases = build_search(params)
        t = cases.hits.inject([]) { |arr, h| arr.push(h.result); arr }
        { :results => t, 
          :count => cases.total }
      end
      @cases = WillPaginate::Collection.create(params[:page], 25, @cases[:count]) { |pager| pager.replace(@cases[:results]) }
    end

    if current_user
      @my_cases = current_user.cases
      @my_bookmarks = current_user.bookmarks_type(Case, ItemCase)
    else
      @my_cases = @my_bookmarks = []
    end

    respond_to do |format|
      format.html do
        if request.xhr?
          @view = "case_obj"
          @collection = @cases
          render :partial => 'shared/generic_block'
        else
          render 'index'
        end
      end
      format.xml  { render :xml => @cases }
    end
  end

  # GET /cases/1
  # GET /cases/1.xml
  def show
    add_stylesheets 'cases'
    add_javascripts 'cases'

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

  def export
    render :layout => 'print'
  end

  # GET /cases/new
  # GET /cases/new.xml
  def new
    @case = Case.new
    @case.case_jurisdiction = CaseJurisdiction.new
    add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_case']

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @case }
    end
  end

  # GET /cases/1/edit
  def edit
    add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_case']
  end

  # POST /cases
  # POST /cases.xml
  def create
    unless params[:case][:tag_list].blank?
      params[:case][:tag_list] = params[:case][:tag_list].downcase
    end
    @case = Case.new(params[:case])

    add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_case']

    respond_to do |format|
      if @case.save
        @case.accepts_role!(:owner, current_user)
        @case.accepts_role!(:creator, current_user)
        flash[:notice] = 'Case was successfully created.'
        format.html { redirect_to "/cases/#{@case.id}" }
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
    # This is not industrial level security - a user could theoretically overwrite the case content of a case they own via URL tampering.
    unless params[:case][:tag_list].blank?
      params[:case][:tag_list] = params[:case][:tag_list].downcase
    end
    add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_case']

    respond_to do |format|
      if @case.update_attributes(params[:case])
        flash[:notice] = 'Case was successfully updated.'
        format.html { redirect_to "/cases/#{@case.id}" }
        format.json  { render :json => {:type => 'cases', :id => @case.id} }
      else
        format.html { render :action => "edit" }
        format.json  { render :xml => @case.errors, :status => :unprocessable_entity }
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
