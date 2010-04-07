class RolesUsers < ActiveRecord::Migration
  def self.up
    create_table :roles_users, :id => false, :force => true do |t|
      t.references  :user
      t.references  :role
      t.timestamps
    end
    [:user_id, :role_id].each do|col|
      add_index :roles_users, col
    end
  end

  def self.down
    drop_table :roles_users
  end
end
