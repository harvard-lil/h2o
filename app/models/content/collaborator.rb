class Content::Collaborator < ApplicationRecord
  self.table_name = :content_collaborators
  ROLES = %w{owner editor}

  belongs_to :user
  belongs_to :content, class_name: 'Content::Node'

  validates_inclusion_of :role, in: ROLES, message: "must be one of: #{ROLES.join ', '}"
end
