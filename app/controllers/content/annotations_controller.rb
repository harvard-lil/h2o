require 'net/http'
require 'uri'

class Content::AnnotationsController < ApplicationController
  before_action :find_annotation, only: [:destroy, :update]
  before_action :find_resource, only: [:index, :create, :destroy, :update]

  def index
    respond_to do |format|
      format.json { render json: @resource.annotations}
    end
  end

  def create
    params = annotation_params

    if params[:kind] == 'link'
      params[:content] = UrlDomainFormatter.format(params[:content])
    end

    annotation = Content::Annotation.create! params.merge(resource: @resource)
    respond_to do |format|
      format.json { render json: {id: annotation.id}}
      format.html {redirect_to annotate_resource_path(@resource.casebook, @resource)}
    end
  end

  def destroy
    if @resource.casebook.draft_mode_of_published_casebook
      if ! new_annotation?
        unpublished_revision = UnpublishedRevision.create(field: "deleted_annotation", value: (@annotation.copy_of.present?? @annotation.copy_of.id: nil),
          casebook_id: @annotation.resource.casebook_id, node_id: @resource.id, node_parent_id: @resource.copy_of.id)
        if ! unpublished_revision.save
          Notifier.object_failure(current_user, unpublished_revision).deliver
        end
      end
    end
    @annotation.destroy

    respond_to do |format|
      format.html { redirect_to annotate_resource_path(@resource.casebook, @resource) }
      format.json { head :no_content }
    end
  end

  def update
    @annotation.update_attributes annotation_params
    respond_to do |format|
      format.html { redirect_to annotate_resource_path(@resource.casebook, @resource) }
      format.json { head :no_content }
    end
  end

  private

  def new_annotation?
    @annotation.created_at > @annotation.resource.casebook.created_at + 5.seconds
  end

  def annotation_params
    params.require(:annotation).permit :kind, :content, :start_paragraph, :end_paragraph, :start_offset, :end_offset
  end

  def find_resource
    @resource = Content::Resource.find(params[:resource_id])
  end

  def find_annotation
    @annotation = Content::Annotation.find(params[:id])
  end
end
