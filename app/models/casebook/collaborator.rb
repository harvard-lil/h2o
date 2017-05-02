# == Schema Information
#
# Table name: casebook_collaborators
#
#  id          :integer          not null, primary key
#  user_id     :integer
#  casebook_id :integer
#  role        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class Casebook::Collaborator < ApplicationRecord
  self.table_name = :casebook_collaborators
  ROLES = %w{owner editor reviewer}

  belongs_to :user
  belongs_to :casebook, class_name: 'Casebook::Generic'

  validates_inclusion_of :role, in: ROLES, message: "must be one of: #{ROLES.join ', '}"
end
