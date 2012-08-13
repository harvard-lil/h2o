class PermissionAssignment < ActiveRecord::Base
  validates_presence_of :user_collection_id, :user_id, :permission_id

  belongs_to :permission
  belongs_to :user
  belongs_to :user_collection
end
