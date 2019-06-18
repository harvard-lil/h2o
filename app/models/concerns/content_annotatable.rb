module ContentAnnotatable
  extend ActiveSupport::Concern

  included do
    has_one :raw_content, as: :source, dependent: :destroy
    has_many :resources, class_name: 'Content::Resource', as: :resource
    has_many :annotations, through: :resources
    before_create :prepare_raw_content, :sanitize_content
    before_update :sanitize_content, if: :content_changed?
    after_update :update_annotation_offsets, if: [:saved_change_to_content?, :annotated?]
  end

  class_methods do
    def annotated
      where("annotations_count > 0")
    end
  end

  def annotated?
    annotations_count > 0
  end

  private

  def prepare_raw_content
    build_raw_content(content: content)
    true
  end

  def sanitize_content
    self.content = HTMLUtils.sanitize(content)
    true
  end

  def update_annotation_offsets
    # https://api.rubyonrails.org/classes/ActiveModel/Dirty.html#method-i-previous_changes
    diffs = Differ.get_diffs(HTMLUtils.parse(previous_changes[:content][0]).text,
                             HTMLUtils.parse(previous_changes[:content][1]).text)

    # the where() selects only annotations that might be affected by the changes
    annotations
      .where("global_end_offset >= ?", Differ.get_first_delta_offset(diffs))
      .each do |a|
      range = (a.global_start_offset..a.global_end_offset)
      new_range = Differ.adjust_range(diffs, range)
      if range != new_range
        a.update global_start_offset: new_range.min,
                 global_end_offset: new_range.max
      end
    end
    true
  end
end
