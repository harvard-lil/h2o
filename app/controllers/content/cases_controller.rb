require 'net/http'
require 'uri'

class Content::CasesController < ApplicationController
  before_action :find_case, if: lambda {params[:case_id].present?}
  before_action :set_page_title, except: [:from_capapi]

  # create a temporary resource to display the case
  layout 'casebooks'
  def show
    unless @case.try :public
      flash[:notice] = "You are not authorized to access this page."
      redirect_to :root and return
    end

    @resource = Content::Resource.new resource: @case
    @content = @resource
    render 'content/resources/show'
  end

  def page_title
    if @case.present?
      if action_name == 'edit'
        I18n.t 'content.titles.cases.edit', case_name_abbreviation: @case.name_abbreviation
      else
        I18n.t 'content.titles.cases.show', case_name_abbreviation: @case.name_abbreviation
      end
    else
      I18n.t 'content.titles.cases.read', case_name_abbreviation: @case.name_abbreviation
    end
  end

  def from_capapi
    params.require :id
    @case = Case.find_by(capapi_id: params[:id]) ||
            Case.create(
              {public: true,
               created_via_import: true}.merge(
                Capapi::ModelHelpers.to_attributes(
                  Capapi::Case.retrieve({id: params[:id],
                                         full_case: "true",
                                         body_format: "html"}))))
    render json: {id: @case.id}
  end

  def find_case
    @case = Case.find(params[:case_id])
  end

  def set_page_title
    @page_title = page_title
  end

  rescue_from ActionController::ParameterMissing do |exception|
    render json: {exception.param => "is required"}, status: 400
  end
end
