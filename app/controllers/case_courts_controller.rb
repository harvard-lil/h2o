class CaseCourtsController < BaseController
  def new
  end

  def create
    @case_court = CaseCourt.new(case_courts_params)

    if @case_court.save
      render :json => { :custom_block => 'case_court_post', 
                        :id => @case_court.id, 
                        :update => false, 
                        :name => @case_court.name, 
                        :error => false 
                      } 
    else
      render :json => { :error => true, 
                        :message => "We could not create this case jurisdiction:<br />#{@case_court.errors.full_messages.join('<br />')}" }
    end
  end

  private
  def case_courts_params
    params.require(:case_court).permit(:id, :name, :name_abbreviation)
  end
end
