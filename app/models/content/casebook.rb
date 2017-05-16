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

# Concrete class for a Casebook, the root node of a table of contents.
# - does not belong to a Casebook
# - has ordinals of []
# - can have children
# - can have collaborators of its own
class Content::Casebook < Content::Node
  default_scope {where(casebook_id: nil)}

  validates :casebook_id, presence: false
  validates_length_of :ordinals, is: 0

  has_many :contents, -> {order :ordinals}, class_name: 'Content::Child', inverse_of: :casebook, foreign_key: :casebook_id

  has_many :collaborators, class_name: 'Content::Collaborator', dependent: :destroy, inverse_of: :content, foreign_key: :content_id
  include Content::Concerns::HasCollaborators
  include Content::Concerns::HasChildren

  def owner
    owners.first
  end

  def owner= user
    collaborators << Content::Collaborator.new(user: user, role: 'owner')
  end

  def title
    super || I18n.t('content.untitled-casebook', id: id)
  end

  def to_param
    "#{id}-#{slug}"
  end
end
