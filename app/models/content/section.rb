# == Schema Information
#
# Table name: content_nodes
#
#  id            :integer          not null, primary key
#  title         :string
#  slug          :string
#  subtitle      :string
#  headnote      :text
#  public        :boolean          default(TRUE), not null
#  casebook_id   :integer
#  ordinals      :integer          default([]), not null, is an Array
#  copy_of_id    :integer
#  is_alias      :boolean
#  resource_type :string
#  resource_id   :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

# Concrete class for a Section, a branch node in a table of contents.
# - is a Child
# - can have Children
# - does not have an associated material resource
class Content::Section < Content::Child
  default_scope {where(resource_id: nil)}

  has_many :contents, ->(section) {where(['ordinals[1:?] = ARRAY[?]', section.ordinals.length, section.ordinals]).where.not(id: section.id).order :ordinals}, class_name: 'Content::Child', primary_key: :casebook_id, foreign_key: :casebook_id
  include Content::Concerns::HasChildren

  def title
    super || default_title
  end

  def default_title
    words = I18n.t('content.section-words').take(ordinals.length)
    words.fill words.last, words.length..(ordinals.length - 1)
    words.zip(ordinals.map(&:humanize).map(&:capitalize)).map {|pair| pair.join ' '}.join ', '
  end

  belongs_to :resource, polymorphic: true, optional: true
  def resource
    raise Exception.new "Section #{ordinal_string} is not a Content::Resource"
  end
end
