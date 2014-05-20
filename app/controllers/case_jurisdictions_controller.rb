class CaseJurisdictionsController < BaseController
  def new
  end

  def edit
  end

  def create
    @case_jurisdiction = CaseJurisdiction.new(case_jurisdictions_params)

    if @case_jurisdiction.save
      render :json => { :custom_block => 'case_jurisdiction_post', 
                        :id => @case_jurisdiction.id, 
                        :update => false, 
                        :name => @case_jurisdiction.name, 
                        :error => false 
                      } 
    else
      render :json => { :error => true, 
                        :message => "We could not create this case jurisdiction:<br />#{@case_jurisdiction.errors.full_messages.join('<br />')}" }
    end
  end

  def update
    if @case_jurisdiction.update_attributes(case_jurisdictions_params)
      render :json => { :custom_block => 'case_jurisdiction_post', 
                        :id => @case_jurisdiction.id, 
                        :update => true,
                        :name => @case_jurisdiction.name, 
                        :error => false 
                      } 
    else
      render :json => { :error => true, 
                        :message => "We could not create this case jurisdiction:<br />#{@case_jurisdiction.errors.full_messages.join('<br />')}" }
    end
  end

  private
  def case_jurisdictions_params
    params.require(:case_jurisdiction).permit(:id, :name, :abbreviation)
  end
end
