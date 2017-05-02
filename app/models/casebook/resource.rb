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

class Casebook::Resource < Casebook::Contents
  default_scope {where.not(material_id: nil)}

  belongs_to :material, polymorphic: true, inverse_of: :casebooks, required: true

  def can_delete?
    true
  end
  def title
    super || material.title
  end
end
