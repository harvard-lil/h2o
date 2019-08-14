class Content::Annotation < ApplicationRecord
  KINDS = %w{elide replace link highlight note}
  KINDS_WITH_CONTENT = %w{replace link note}

  belongs_to :resource, class_name: 'Content::Resource', required: true
  accepts_nested_attributes_for :resource
  
  has_one :unpublished_revision

  validates_inclusion_of :kind, in: KINDS, message: "must be one of: #{KINDS.join ', '}"
  validates :content, presence: true, if: Proc.new { |a| KINDS_WITH_CONTENT.include? a.kind }

  before_save :update_paragraph_based_offsets, if: :new_record_or_global_offset_changed?
  after_create :update_resource_counter_cache
  after_destroy :update_resource_counter_cache, unless: :destroyed_by_association

  def copy_of
    resource.copy_of.annotations.find_by(start_paragraph: self.start_paragraph, end_paragraph: self.end_paragraph, start_offset: self.start_offset, end_offset: self.end_offset, kind: self.kind)
  end

  def exists_in_published_casebook?
    resource.casebook.draft_mode_of_published_casebook && copy_of.present?
  end

  def to_api_response
    {id: id,
     content: content}
  end

  def content=(value)
    if kind == 'link' && value.present?
      value = UrlDomainFormatter.format(value)
    end

    super(value)
  end

  # Serialize to json without including all the columns
  # https://blog.arkency.com/how-to-overwrite-to-json-as-json-in-active-record-models-in-rails/
  def as_json(*)
    super.except("start_paragraph", "end_paragraph").tap do |hash|
      hash["start_offset"] = hash.delete("global_start_offset")
      hash["end_offset"] = hash.delete("global_end_offset")
    end
  end

  private

  def new_record_or_global_offset_changed?
    # returns true if the global offsets have changed and we're not
    # in the midst of creating a new record where the paragraph offsets
    # have already been populated, as is the case when cloning
    (global_start_offset_changed? || global_end_offset_changed?) &&
      (persisted? || start_offset.blank?)
  end

  def update_paragraph_based_offsets
    nodes = HTMLUtils.parse(resource.resource.content).at('body').children
    assign_attributes AnnotationConverter.global_offsets_to_node_offsets(nodes, global_start_offset, global_end_offset)
  end

  def update_resource_counter_cache
    resource.resource.update_column :annotations_count,
                                    resource.resource.annotations.count
  end
end
