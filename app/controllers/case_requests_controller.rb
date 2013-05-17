class CaseRequestsController < ApplicationController

  before_filter :require_user
  before_filter :load_single_resource, :only => [:destroy]

  def new
    add_javascripts ['new_case_request']
    @case_request = CaseRequest.new

    respond_to do |format|
      format.html
    end
  end

  def create
    @case_request = CaseRequest.new(params[:case_request])
    
    respond_to do |format|
      if @case_request.save
        @case_request.accepts_role!(:owner, current_user)
        @case_request.accepts_role!(:creator, current_user)
        flash[:notice] = 'Case Request was successfully created.'
        format.html { redirect_to cases_path }
      else
        format.html { render :action => 'new' }
      end
    end
  end

  def destroy
    Notifier.deliver_case_request_notify_rejected(@case_request)
    @case_request.destroy
    respond_to do |format|
      format.html { redirect_to(cases_url) }
      format.xml  { head :ok }
      format.json { render :json => {} }
    end
  end
end
