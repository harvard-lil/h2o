# == Schema Information
#
# Table name: casebook_collaborators
#
#  id          :integer          not null, primary key
#  user_id     :integer
#  casecasebook_id :integer
#  role        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

# Join class for users with privileges on a Content::Node
# - associates a single User with a single Node (generally a Casebook)
# - has an associated role which defines the privileges
class Content::Collaborator < ApplicationRecord
  self.table_name = :content_collaborators
  ROLES = %w{owner editor reviewer}

  belongs_to :user
  belongs_to :content, class_name: 'Content::Node'

  validates_inclusion_of :role, in: ROLES, message: "must be one of: #{ROLES.join ', '}"
end
