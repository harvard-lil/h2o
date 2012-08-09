class PermissionAssignment < ActiveRecord::Base
  validates_presence_of :user_collection_id, :user_id, :permission_id
end
