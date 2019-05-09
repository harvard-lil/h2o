require 'net/http'
require 'uri'

class Content::AnnotationsController < ApplicationController
  before_action :find_annotation, only: [:destroy, :update]
  before_action :find_resource, only: [:index, :create, :destroy, :update]
  before_action :check_public, only: [:index]

  def index
    breakpoints = AnnotationConverter.paragraph_nodes_to_breakpoints(@resource.paragraph_nodes)

    json = @resource.annotations.as_json
      .select { |a|
      # remove annotations that have impossible placements
      ["start", "end"].reduce(true) { |m, s|
        m && @resource.paragraph_nodes[a["#{s}_paragraph"]].text.length >= a["#{s}_offset"]
      }
    }.map { |a|
      # convert from paragraph to doc level offsets
      a.merge(
        ["start", "end"].map { |s|
          ["#{s}_offset", a["#{s}_offset"] + breakpoints[a["#{s}_paragraph"]]]
        }.to_h).except("start_paragraph", "end_paragraph")
    }

    respond_to do |format|
      format.json { render json: json }
    end
  end

  def create
    params = annotation_params
               .merge(resource: @resource)
               .merge(AnnotationConverter.global_offsets_to_paragraph_offsets(@resource.paragraph_nodes, annotation_params[:start_offset], annotation_params[:end_offset]))

    annotation = Content::Annotation.create! params
    respond_to do |format|
      format.json { render json: annotation.to_api_response }
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
