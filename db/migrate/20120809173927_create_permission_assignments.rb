class CreatePermissionAssignments < ActiveRecord::Migration
  def self.up
    create_table :permission_assignments do |t|
      t.references :user_collection
      t.references :user
      t.references :permission
      t.timestamps
    end
  end

  def self.down
    drop_table :permission_assignments
  end
end
