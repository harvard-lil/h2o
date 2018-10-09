class Content::Section < Content::Child
  default_scope {where(resource_id: nil)}

  belongs_to :resource, polymorphic: true, optional: true

  has_many :contents, ->(section) {where(['ordinals[1:?] = ARRAY[?]', section.ordinals.length, section.ordinals]).where.not(id: section.id).order :ordinals}, class_name: 'Content::Child', primary_key: :casebook_id, foreign_key: :casebook_id
  include Content::Concerns::HasChildren

  def title
    super || I18n.t('content.untitled-section')
  end

  def resource
    raise Exception.new "Section #{ordinal_string} is not a Content::Resource"
  end

  def resources_have_annotations?
    resources.each do |resource|
      if resource.annotations.any?
        return true
      end
    end
    false
  end
end
