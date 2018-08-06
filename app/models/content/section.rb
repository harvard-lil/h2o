class Content::Section < Content::Child
  default_scope {where(resource_id: nil)}

  has_many :contents, ->(section) {where(['ordinals[1:?] = ARRAY[?]', section.ordinals.length, section.ordinals]).where.not(id: section.id).order :ordinals}, class_name: 'Content::Child', primary_key: :casebook_id, foreign_key: :casebook_id
  has_many :unpublished_revisions, dependent: :destroy
  include Content::Concerns::HasChildren

  def title
    super || I18n.t('content.untitled-section')
  end

  belongs_to :resource, polymorphic: true, optional: true
  def resource
    raise Exception.new "Section #{ordinal_string} is not a Content::Resource"
  end
end
