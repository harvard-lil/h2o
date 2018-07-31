class Content::Fixture < Content::Node
  has_many :collaborators, class_name: 'Content::Collaborator', dependent: :destroy, inverse_of: :content, foreign_key: :content_id
  # include Content::Concerns::HasCollaborators

  belongs_to :casebook, class_name: 'Content::Fixture', optional: true
  belongs_to :resource, polymorphic: true, inverse_of: :casebooks, optional: true
end
