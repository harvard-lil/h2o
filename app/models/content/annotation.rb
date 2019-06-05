class Content::Annotation < ApplicationRecord
  KINDS = %w{elide replace link highlight note}
  KINDS_WITH_CONTENT = %w{replace link note}

  belongs_to :resource, class_name: 'Content::Resource', required: true
  has_one :unpublished_revision

  validates_inclusion_of :kind, in: KINDS, message: "must be one of: #{KINDS.join ', '}"
  validates :content, presence: true, if: Proc.new { |a| KINDS_WITH_CONTENT.include? a.kind }

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

  def as_json(*)
    super.except("start_paragraph", "end_paragraph").tap do |hash|
      hash["start_offset"] = hash.delete("global_start_offset")
      hash["end_offset"] = hash.delete("global_end_offset")
    end
  end

  private

  def update_resource_counter_cache
    resource.resource.update_column :annotations_count,
                                    resource.resource.annotations.count
  end
end
