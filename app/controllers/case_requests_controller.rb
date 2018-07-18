class CaseRequestsController < BaseController
  protect_from_forgery :except => [:destroy]

  def new
  end

  def create
    @case_request = CaseRequest.new(case_requests_params)
    @case_request.user = current_user

    if @case_request.save
      flash[:notice] = 'Case Request was successfully created.'
      redirect_to cases_path
    else
      render :action => 'new'
    end
  end

  def destroy
    Notifier.case_request_notify_rejected(@case_request).deliver_later
    @case_request.destroy
    respond_to do |format|
      format.html { redirect_to(cases_url) }
      format.xml  { head :ok }
      format.json { render :json => {} }
    end
  end
  private
  def case_requests_params
    params.require(:case_request).permit(:name, :decision_date, :author, :case_jurisdiction_id,
                                         :docket_number, :volume, :reporter, :page, :bluebook_citation,
                                         :status)
  end
end
