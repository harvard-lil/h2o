# == Schema Information
#
# Table name: roles_users
#
#  user_id    :integer
#  role_id    :integer
#  created_at :datetime
#  updated_at :datetime
#

class RolesUser < ActiveRecord::Base
  belongs_to :role
  belongs_to :user
end
