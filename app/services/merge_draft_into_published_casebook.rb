class MergeDraftIntoPublishedCasebook
  def self.perform(draft, published)
    new(draft, published).perform
  end

  def initialize(draft, published)
    @draft = draft
    @published = published
  end

  def perform
    published_ordinals
    new_resources
    unpublished_revisions
    new_and_updated_annotations
    deleted_annotations
    content_collaborators

    draft.destroy

    published
  end

  # private

  attr_reader :draft, :published

  def published_ordinals
    resources = draft.resources.where("created_at < ?", draft.created_at)

    resources.each do |resource|
      parent_resource = resource.copy_of
      if resource.ordinals != parent_resource.ordinals
        parent_resource.update(ordinals: resource.ordinals)
      end
    end
  end

  def new_resources
    new_resources = draft.resources.where(copy_of_id: nil)

    if new_resources.present?
      new_resources.each do |resource|
        new_resource = resource.dup
        new_resource.update(casebook_id: published.id)
      end
    end
  end

  def unpublished_revisions
    revisions.where.not(field: "deleted_annotation").each do |revision|
      resource = Content::Node.find(revision.node_parent_id)
      if %w(url content).include? revision.field
        resource.resource.update("#{revision.field}": revision.value)
      else
        resource.update("#{revision.field}": revision.value)
      end
      revision.destroy
    end
  end

  def new_and_updated_annotations
    resource_ids = self.resources.pluck(:id)
    new_or_updated_annotations = Content::Annotation.where(resource_id: resource_ids).where("updated_at > ?", self.created_at + 1.minute)

    new_or_updated_annotations.each do |annotation|
      if annotation.exists_in_published_casebook?
        Content::Annotation.destroy(annotation.copy_of_id)
        parent_resource = Content::Annotation.find(annotation.copy_of_id).resource
        annotation.update(resource_id: parent_resource.id)
      elsif ! annotation.resource.exists_in_published_casebook?


        annotation.dup
        resource = Content::Resource.find(annotation.resource.copy_of_id) # unless it's on a new resource
        annotation.update(resource_id: resource.id)
      end
    end
  end

  def deleted_annotations
    revisions.where(field: "deleted_annotation").each do |revision|
      Content::Annotation.destroy(revision.value)
    end
  end

  def content_collaborators
    ## but what if someone deletes a collab 

    new_collaborators = Content::Collaborator.where(content_id: self.id).where("created_at > ?", self.created_at)

    if new_collaborators.present?
      new_collaborators.each do |collaborator|
        new_collaborator = collaborator.dup
        new_collaborator.update_attributes(content_id: published.id)
      end
    end
  end
end
