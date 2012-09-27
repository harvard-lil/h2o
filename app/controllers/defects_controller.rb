class DefectsController < ApplicationController
  
  before_filter :require_user

  def new
    @defect = Defect.new
  end

  def create
    @defect = Defect.new(params[:defect])

    if @defect.save
      render :json => { :error => false }
    else
      render :json => { :error => true, :message => "We couldn't add that defect. Sorry!<br/><br/>#{@defect.errors.full_messages.join('<br/><br/>')}" }
    end
  end

  def destroy
    Defect.find(params[:id]).destroy
    render :json => {}
  end
end
