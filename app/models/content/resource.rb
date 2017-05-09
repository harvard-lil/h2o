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
#  casebook_id       :integer
#  ordinals      :integer          default([]), not null, is an Array
#  copy_of_id    :integer
#  is_alias      :boolean
#  resource_type :string
#  resource_id   :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

# Concrete class for a Resource, a leaf node in a table of contents.
# - is a Child
# - cannot have Children
# - contains a reference to a single material resource, i.e. a Case, TextBlock, or Link
class Content::Resource < Content::Child
  default_scope {where.not(resource_id: nil)}

  belongs_to :resource, polymorphic: true, inverse_of: :casebooks, required: true

  def can_delete?
    true
  end
  def title
    super || resource.title
  end
end
