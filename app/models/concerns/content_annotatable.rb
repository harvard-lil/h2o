module ContentAnnotatable
  extend ActiveSupport::Concern

  included do
    has_one :raw_content, as: :source, dependent: :destroy
    before_create :build_raw_content_and_assign_sanitized
    after_update :update_annotation_offsets
  end

  def annotations
    Content::Annotation
      .joins(:resource)
      .where(content_nodes: {resource_type: self.class.name, resource_id: id})
  end

  class_methods do
    def annotated
      where('id IN (SELECT DISTINCT content_nodes.resource_id FROM content_nodes INNER JOIN content_annotations ON content_nodes.id = content_annotations.resource_id WHERE content_nodes.resource_type = ?)', self.name)
    end
  end

  private

  def build_raw_content_and_assign_sanitized
    build_raw_content(content: content)
    self.content = HTMLFormatter.process(raw_content.content)
    true
  end

  def update_annotation_offsets
  end
end
