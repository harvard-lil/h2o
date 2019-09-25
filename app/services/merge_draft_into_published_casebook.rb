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
    ActiveRecord::Base.transaction do
      remove_deleted_contents
      add_new_contents
      reflow_published_ordinals
      merge_in_unpublished_revisions
      new_and_updated_annotations
      deleted_annotations
      # content_collaborators
      draft.destroy

      {success: true, casebook: published}
    end
  rescue => e
    Notifier.merge_failed(draft.owner, draft, published, e, e.backtrace).deliver
    Rails.logger.warn "Casebook merge failure: #{e.inspect}"
    {success: false, casebook: draft}
  end

  def remove_deleted_contents
    draft_contents_copy_of_ids = draft.contents.pluck(:copy_of_id).compact.uniq

    published.contents.each do |published_content|
      if draft_contents_copy_of_ids.exclude? published_content.id
        published_content.destroy!
      end
    end
  end

  def reflow_published_ordinals
    previously_created_contents.each do |content|
      parent_content = content.copy_of
      if content.ordinals != parent_content.ordinals
        parent_content.update!(ordinals: content.ordinals)
      end
    end
  end

  def add_new_contents
    if new_contents.present?
      new_contents.each do |content|
        new_content = content.dup
        new_content.update!(casebook_id: published.id)
      end
    end
  end

  def merge_in_unpublished_revisions
    resource_revisions.each do |revision|
      resource = Content::Node.find(revision.node_parent_id)
      if casebook_detail?(revision.field)
        resource.update!("#{revision.field}": revision.value)
      else
        resource.resource.update!("#{revision.field}": revision.value)
      end
      revision.destroy!
    end
  end

  def new_and_updated_annotations
    new_or_updated_annotations.each do |annotation|
      published_resource = annotation.resource.copy_of

      if annotating_new_resource?(annotation)
        published_resource = published.resources.find_by(resource_id: annotation.resource.resource_id)
      elsif annotation.exists_in_published_casebook?
        published_annotation = published_resource.annotations.find_by(start_paragraph: annotation.start_paragraph, end_paragraph: annotation.end_paragraph,
          start_offset: annotation.start_offset, end_offset: annotation.end_offset)
        published_annotation.destroy!
      end

      annotation.update!(resource_id: published_resource.id)
    end
  end

  def deleted_annotations
    revisions.where(field: "deleted_annotation").each do |revision|
      ancestor_annotation = Content::Annotation.find_by(:id => revision.value.to_i)
      if ancestor_annotation
        ancestor_annotation.destroy!
      end
      revision.destroy!
    end
  end

  def content_collaborators
    #if a user is deleted, added or role is changed
    #multiple collaborator functionality doesn't exist yet so
    #holding this method for the future
  end

  private

  def previously_created_contents
    draft.contents.where.not(copy_of_id: nil)
  end

  def new_contents
    draft.contents.where(copy_of_id: nil)
  end

  def resource_revisions
    revisions.where.not(field: "deleted_annotation")
  end

  def casebook_detail?(field)
    %w(url content).exclude? field
  end

  def draft_resource_ids
    draft.resources.where(resource_type: %w(TextBlock Case)).pluck(:id)
  end

  def new_or_updated_annotations
    annotations = []

    all_annotations = Content::Annotation.where(resource_id: draft_resource_ids)

    all_annotations.each do |annotation|
      if annotating_new_resource?(annotation) || new_annotation?(annotation) || updated_annotation?(annotation)
        annotations << annotation
      end
    end

    annotations
  end

  def updated_annotation?(annotation)
    annotation.created_at != annotation.updated_at
  end

  def new_annotation?(annotation)
    annotation.copy_of.nil?
  end

  def annotating_new_resource?(annotation)
    ! annotation.resource.copy_of.present?
  end
end
