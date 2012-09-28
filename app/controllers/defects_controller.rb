class DefectsController < ApplicationController
  
  before_filter :require_user

  def create
    @defect = Defect.new(params[:defect])

    if @defect.save
      render :json => { :error => false }
    else
      render :json => { :error => true, :message => "We couldn't record that error. A description of the error is required." }
    end
  end

  def destroy
    Defect.find(params[:id]).destroy
    render :json => {}
  end
end
