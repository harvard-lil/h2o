class CaseDocketNumbersController < BaseController

  before_filter :require_user, :except => [:index, :show]
  
  access_control do
    allow :case_admin, :admin, :superadmin
    allow all, :to => [:show, :index]
  end

  # GET /case_docket_numbers
  # GET /case_docket_numbers.xml
  def index
    @case_docket_numbers = CaseDocketNumber.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @case_docket_numbers }
    end
  end

  # GET /case_docket_numbers/1
  # GET /case_docket_numbers/1.xml
  def show
    @case_docket_number = CaseDocketNumber.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @case_docket_number }
    end
  end

  # GET /case_docket_numbers/new
  # GET /case_docket_numbers/new.xml
  def new
    @case_docket_number = CaseDocketNumber.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @case_docket_number }
    end
  end

  # GET /case_docket_numbers/1/edit
  def edit
    @case_docket_number = CaseDocketNumber.find(params[:id])
  end

  # POST /case_docket_numbers
  # POST /case_docket_numbers.xml
  def create
    @case_docket_number = CaseDocketNumber.new(params[:case_docket_number])

    respond_to do |format|
      if @case_docket_number.save
        flash[:notice] = 'CaseDocketNumber was successfully created.'
        format.html { redirect_to(@case_docket_number) }
        format.xml  { render :xml => @case_docket_number, :status => :created, :location => @case_docket_number }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @case_docket_number.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /case_docket_numbers/1
  # PUT /case_docket_numbers/1.xml
  def update
    @case_docket_number = CaseDocketNumber.find(params[:id])

    respond_to do |format|
      if @case_docket_number.update_attributes(params[:case_docket_number])
        flash[:notice] = 'CaseDocketNumber was successfully updated.'
        format.html { redirect_to(@case_docket_number) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @case_docket_number.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /case_docket_numbers/1
  # DELETE /case_docket_numbers/1.xml
  def destroy
    @case_docket_number = CaseDocketNumber.find(params[:id])
    @case_docket_number.destroy

    respond_to do |format|
      format.html { redirect_to(case_docket_numbers_url) }
      format.xml  { head :ok }
    end
  end
end
