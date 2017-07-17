require 'net/http'
require 'uri'

class Content::AnnotationsController < ApplicationController
  before_action :find_annotation, only: [:destroy, :update]
  before_action :find_resource, only: [:create, :destroy, :update]

  def create
    Content::Annotation.create! annotation_params.merge(resource: @resource)
    redirect_to casebook_section_path(@resource.casebook, @resource)
  end

  def destroy
    @annotation.destroy
    redirect_to casebook_section_path(@resource.casebook, @resource)
  end

  def update
    @annotation.update_attributes annotation_params
    redirect_to casebook_section_path(@resource.casebook, @resource)
  end

  private

  def annotation_params
    params.require(:annotation).permit :kind, :content, :start_p, :end_p, :start_offset, :end_offset
  end

  def find_resource
    @resource = Content::Resource.find(params[:resource_id])
  end

  def find_annotation
    @annotation = Content::Annotation.find(params[:id])
  end
end
