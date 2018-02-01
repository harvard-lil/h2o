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

# Convenience class only used by fixtures/content_nodes.yml
# - allows specification of Casebooks, Sections and Resources, which have mutually exclusive constraints, using a single fixture format
class Content::Fixture < Content::Node
  has_many :collaborators, class_name: 'Content::Collaborator', dependent: :destroy, inverse_of: :content, foreign_key: :content_id
  # include Content::Concerns::HasCollaborators

  belongs_to :casebook, class_name: 'Content::Fixture', optional: true
  belongs_to :resource, polymorphic: true, inverse_of: :casebooks, optional: true
end
