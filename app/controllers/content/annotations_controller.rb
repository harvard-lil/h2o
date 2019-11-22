require 'net/http'
require 'uri'

class Content::AnnotationsController < ApplicationController
  before_action :find_annotation, only: [:destroy, :update]
  before_action :find_resource, only: [:index, :create, :destroy, :update]
  before_action :check_public, only: [:index]

  def index
    respond_to do |format|
      format.json { render json: @resource.annotations }
    end
  end

  def create
    # This is parsed, but doesn't seem to be in use... commenting out for now.
    # nodes = HTMLUtils.parse(@resource.resource.content).at('body').children
    params = annotation_params
               .except(:start_offset, :end_offset)
               .merge(resource: @resource)
               .merge(global_start_offset: annotation_params[:start_offset],
                      global_end_offset: annotation_params[:end_offset])

    annotation = Content::Annotation.create! params
    respond_to do |format|
      format.json { render json: annotation.to_api_response }
      format.html { redirect_to annotate_resource_path(@resource.casebook, @resource) }
    end
  end

  def destroy
    if @resource.casebook.draft_mode_of_published_casebook
      copy_of = @annotation.copy_of
      if copy_of
        unpublished_revision = UnpublishedRevision.create(field: "deleted_annotation", value: copy_of.id,
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
      format.json { render json: @annotation.to_api_response }
    end
  end

  private

  def check_public
    @resource.casebook.public || check_authorized
  end

  def check_authorized
    return if current_user && (@resource.casebook.has_collaborator?(current_user.id) ||
                               current_user.superadmin?)
    respond_to do |format|
      format.json { head :forbidden }
    end
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
