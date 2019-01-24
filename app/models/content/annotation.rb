class Content::Annotation < ApplicationRecord
  KINDS = %w{elide replace link highlight note}
  belongs_to :resource, class_name: 'Content::Resource', required: true
  has_one :unpublished_revision

  validates_inclusion_of :kind, in: KINDS, message: "must be one of: #{KINDS.join ', '}"
  validates :content, presence: true, if: Proc.new { |a| a.kind == "replace" }

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
    value = UrlDomainFormatter.format(value) if kind == 'link'
    super(value)
  end
end
