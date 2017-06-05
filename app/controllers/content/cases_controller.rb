require 'net/http'
require 'uri'

class Content::CasesController < ApplicationController
  # create a temporary resource to display the case
  layout 'casebooks'
  def show
    @section = Content::Resource.new resource: Case.find(params[:case_id])
    @content = @section
    render 'content/show'
  end

end
