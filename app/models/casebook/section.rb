# == Schema Information
#
# Table name: casebooks
#
#  id            :integer          not null, primary key
#  title         :string           default("Untitled casebook"), not null
#  slug          :string
#  subtitle      :string
#  headnote      :text
#  public        :boolean          default(TRUE), not null
#  root_id       :integer
#  ordinals      :integer          default([]), not null, is an Array
#  copy_of_id    :integer
#  is_alias      :boolean
#  material_type :string
#  material_id   :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class Casebook::Section < Casebook::Contents
  default_scope {where(material_id: nil)}

  has_many :contents, ->(section) {where(['ordinals[1:?] = ARRAY[?]', section.ordinals.length, section.ordinals]).where.not(id: section.id).order :ordinals}, class_name: 'Casebook::Contents', primary_key: :root_id, foreign_key: :root_id
  include Casebook::Concerns::Contents

  def title
    super || default_title
  end

  def default_title
    words = I18n.t('casebooks.section-words').take(ordinals.length)
    words.fill words.last, words.length..(ordinals.length - 1)
    words.zip(ordinals.map(&:humanize).map(&:capitalize)).map {|pair| pair.join ' '}.join ', '
  end
end
