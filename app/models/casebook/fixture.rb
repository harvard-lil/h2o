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

# This is a convenience class only used by fixtures/casebooks.yml
class Casebook::Fixture < Casebook::Generic
  belongs_to :root, class_name: 'Casebook::Fixture', optional: true
end
