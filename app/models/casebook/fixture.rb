# == Schema Information
#
# Table name: casebooks
#
#  id            :integer          not null, primary key
#  title         :string
#  slug          :string
#  subtitle      :string
#  headnote      :text
#  public        :boolean          default(TRUE), not null
#  book_id       :integer
#  ordinals      :integer          default([]), not null, is an Array
#  copy_of_id    :integer
#  is_alias      :boolean
#  resource_type :string
#  resource_id   :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

# This is a convenience class only used by fixtures/casebooks.yml
class Casebook::Fixture < Casebook::Generic
  belongs_to :book, class_name: 'Casebook::Fixture', optional: true
  belongs_to :resource, polymorphic: true, inverse_of: :casebooks, optional: true
end
