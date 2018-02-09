class MergeDraftIntoPublishedCasebook
  attr_reader :draft, :published, :revisions

  def self.perform(draft, published)
    new(draft, published).perform
  end

  def initialize(draft, published)
    @draft = draft
    @published = published
    @revisions = UnpublishedRevision.where(casebook_id: @draft.id)
  end

  def perform
    reflow_published_ordinals
    add_new_resources
    merge_in_unpublished_revisions
    new_and_updated_annotations
    deleted_annotations
    # content_collaborators

    draft.destroy

    published
  end

  def reflow_published_ordinals
    previously_created_resources.each do |resource|
      parent_resource = resource.copy_of
      if resource.ordinals != parent_resource.ordinals
        parent_resource.update(ordinals: resource.ordinals)
      end
    end
  end

  def add_new_resources
    if new_resources.present?
      new_resources.each do |resource|
        new_resource = resource.dup
        new_resource.update(casebook_id: published.id)
      end
    end
  end

  def merge_in_unpublished_revisions
    resource_revisions.each do |revision|
      resource = Content::Node.find(revision.node_parent_id)
      if casebook_detail?(revision.field)
        resource.update("#{revision.field}": revision.value)
      else
        resource.resource.update("#{revision.field}": revision.value)
      end
      revision.destroy
    end
  end

  def new_and_updated_annotations
    new_or_updated_annotations.each do |annotation|
      if exists_in_published_casebook?(annotation)
        Content::Annotation.destroy(annotation.copy_of_id)
        parent_resource = annotation.copy_of.resource
        annotation.update(resource_id: parent_resource.id)
      elsif ! annotation.resource.exists_in_published_casebook?
        annotation.dup
        published_resource = annotation.resource.copy_of # test on a new resource 
        annotation.update(resource_id: published_resource.id)
      end
    end
  end

  def deleted_annotations
    revisions.where(field: "deleted_annotation").each do |revision|
      Content::Annotation.destroy(revision.annotation.id)
    end
  end

  def content_collaborators
    #if a user is deleted, added or role is changed
    #multiple collaborator functionality doesn't exist yet so
    #holding this method for the future
  end

  private

  def previously_created_resources
    draft.resources.where.not(copy_of_id: nil)
  end

  def new_resources
    draft.resources.where(copy_of_id: nil)
  end

  def resource_revisions
    revisions.where.not(field: "deleted_annotation")
  end

  def casebook_detail?(field)
    %w(url content).exclude? field
  end

  def draft_resource_ids
    draft.resources.pluck(:id)
  end

  def new_or_updated_annotations
    Content::Annotation.where(resource_id: draft_resource_ids).where("updated_at > ?", draft.created_at + 1.minute)
  end

  def exists_in_published_casebook?(annotation)
    annotation.copy_of.present? && annotation.copy_of.resource.casebook == published
  end
end
