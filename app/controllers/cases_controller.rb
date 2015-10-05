class CasesController < BaseController
  protect_from_forgery except: [:approve, :destroy]

  cache_sweeper :case_sweeper
  caches_page :show, :if => Proc.new { |c| c.instance_variable_get('@case').public }

  def embedded_pager
    super Case
  end

  def index
    common_index Case
  end

  def show
    @page_cache = true
    @editability_path = access_level_case_path(@case)
  end

  def access_level
    if current_user
      render :json => {
        :can_edit => can?(:edit, @case),
        :custom_block => 'case_afterload'
      }
    else
      render :json => {
        :can_edit => false,
        :custom_block => 'case_afterload'
      }
    end
  end

  def export
    render :layout => 'print'
  end

  def approve
    @case.approve!
    render :json => {}
  end

  def new
    @case = Case.new
    if params.has_key?(:case_request_id)
      case_request = CaseRequest.where(:id => params[:case_request_id]).first
      [:full_name, :decision_date, :author, :case_jurisdiction_id].each do |attr|
        @case.send("#{attr}=", case_request.send(attr))
      end
      @case.case_request = case_request
      @case.case_docket_numbers = [CaseDocketNumber.new({ :docket_number => case_request.docket_number })]
      @case.case_citations = [CaseCitation.new({ :volume => case_request.volume, :reporter => case_request.reporter, :page => case_request.page })]
    end
  end

  def upload
    if request.get?
      respond_to do |format|
        format.html { render :template => 'cases/upload'}
        format.xml  { render :xml => @case }
      end
    else
      @case = Case.new_from_xml_file(params[:file])
      if @case.save
        handle_successful_save
      else
        flash[:notice] = @case.errors.full_messages.join(", ")
        render :template => "cases/upload"
      end
    end
  end

  def edit
  end

  def create
    @case = Case.new(cases_params)
    @case.user = User.where(login: 'h2ocases').first

    if @case.save
      @case.approve! if params.has_key?(:approve)
      handle_successful_save
    else
      render :action => "new"
    end
  end

  def update
    # This is not industrial level security - a user could theoretically overwrite the case content of a case they own via URL tampering.
    #<=This ensures that version is incremented when docket numbers or citations are only updated
    @case.updated_at = Time.now 

    if @case.update_attributes(cases_params)
      @case.approve! if params.has_key?(:approve)
      if @case.public
        flash[:notice] = 'Case was successfully updated.'
        redirect_to "/cases/#{@case.id}"
      else
        flash[:notice] = 'Case was successfully updated. It must be approved before it is visible.'
        redirect_to "/users/#{current_user.id}\#p_pending_cases"
      end
    else
      render :action => "edit"
    end
  end

  def destroy
    if @case.deleteable?
      @case.destroy
      json = {}
    else
      json = {
        :error => true,
        :message => 'Cannot delete this Case because it has been used to create an Annotated Item'
      }
    end
    render :json => json
  end

  private
  def handle_successful_save
    @case.case_request.approve! if @case.case_request

    if @case.public
      Notifier.case_notify_approved(@case, @case.case_request).deliver if @case.case_request
      redirect_to "/cases/#{@case.id}"
    else
      flash[:notice] = 'Case was successfully created. It must be approved before it is visible.'
      redirect_to cases_url
    end
  end

  def cases_params
    params.require(:case).permit(:short_name, :full_name, :decision_date, 
                                 :author, :case_jurisdiction_id, :content, :case_request_id,
                                 case_docket_numbers_attributes: [ :docket_number, :id, :_destroy ],
                                 case_citations_attributes: [ :volume, :page, :reporter, :id, :_destroy])
  end
end
