module ContentAnnotatable
  extend ActiveSupport::Concern

  included do
    has_one :raw_content, as: :source, dependent: :destroy
    has_many :resources, class_name: 'Content::Resource', as: :resource
    has_many :annotations, through: :resources
    before_create :build_raw_content_and_assign_sanitized
    after_update :update_annotation_offsets, if: :saved_change_to_content?
  end

  class_methods do
    def annotated
      where('id IN (SELECT DISTINCT content_nodes.resource_id FROM content_nodes INNER JOIN content_annotations ON content_nodes.id = content_annotations.resource_id WHERE content_nodes.resource_type = ?)', self.class.name)
    end
  end

  private

  def build_raw_content_and_assign_sanitized
    build_raw_content(content: content)
    self.content = HTMLFormatter.process(raw_content.content)
    true
  end

  def update_annotation_offsets
    diffs = DiffHelpers.get_diffs(Nokogiri::HTML(previous_changes[:content][0]).text,
                                  Nokogiri::HTML(previous_changes[:content][1]).text)

    # the where() selects only annotations that might be affected by the changes
    annotations
      .where("global_end_offset >= ?", DiffHelpers.get_first_delta_offset(diffs))
      .each do |a|
      range = (a.global_start_offset..a.global_end_offset)
      new_range = DiffHelpers.adjust_range(diffs, range)
      if range != new_range
        a.update global_start_offset: new_range.min,
                 global_end_offset: new_range.max
      end
    end
    true
  end
end
