# == Schema Information
#
# Table name: permission_assignments
#
#  id                 :integer          not null, primary key
#  user_collection_id :integer
#  user_id            :integer
#  permission_id      :integer
#  created_at         :datetime
#  updated_at         :datetime
#

class PermissionAssignment < ActiveRecord::Base
  validates_presence_of :user_collection_id, :user_id, :permission_id

  belongs_to :permission
  belongs_to :user
  belongs_to :user_collection
end
