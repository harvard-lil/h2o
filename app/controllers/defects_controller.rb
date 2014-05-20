class DefectsController < ApplicationController
  protect_from_forgery :except => [:destroy]

  def create
    @defect = Defect.new(defects_params)
    @defect.user = current_user

    if @defect.save
      render :json => { :error => false }
    else
      render :json => { :error => true, :message => "We couldn't record that error. A description of the error is required." }
    end
  end

  def destroy
    @defect.destroy
    render :json => {}
  end

  private
  def defects_params
    params.require(:defect).permit(:description, :reportable_id,  :reportable_type)
  end
end
