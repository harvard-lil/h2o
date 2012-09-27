class DefectsController < ApplicationController
  
  before_filter :require_user

  def new
    @defect = Defect.new
  end

  def create
    @defect = Defect.new(params[:defect])

	respond_to do |format|
	  if @defect.save
        format.json { render :json =>  @defect.to_json() }
      else
        format.json { render :text => "We couldn't add that defect. Sorry!<br/><br/>#{@defect.errors.full_messages.join('<br/><br/>')}", :status => :unprocessable_entity }
      end
	end
  end

  def destroy
    @defect = Defect.find(params[:id])
    @defect.destroy
    respond_to do |format|
      format.html { redirect_to(cases_url) }
      format.xml  { head :ok }
      format.json { render :json => {} }
    end
  end
end
