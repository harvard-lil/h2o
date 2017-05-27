class ResponsesController < ApplicationController
  protect_from_forgery :except => [:create, :destroy]

  def create
    params[:response] = {
      :user_id => current_user.id,
      :content => params[:content]
    }
    if params.has_key?(:text_block_id)
      params[:response][:resource_type] = 'TextBlock'
      params[:response][:resource_id] = params[:text_block_id]
    end

    response = Response.new(responses_params)

    if response.save
      render :json => {}
    else
      render :json => { :error => true }
    end
  rescue Exception => e
    render :json => { :error => true }
  end

  def destroy
    @response.destroy

    render :json => {}
  rescue Exception => e
    logger.warn("Could not delete annotation: #{e.inspect}")
    render :json => { :error => "There seems to have been a problem deleting that item. #{e.inspect}" }, :status => :unprocessable_entity
  end

  private
  def responses_params
    params.require(:response).permit(:user_id, :content, :resource_id, :resource_type)
  end
end
