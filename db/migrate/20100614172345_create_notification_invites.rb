class CreateNotificationInvites < ActiveRecord::Migration
  def self.up
    create_table :notification_invites do |t|
      t.integer :user_id
      t.integer :resource_id
      t.string  :resource_type
      t.string  :email_address, :limit => 1024
      t.string  :tid, :limit => 1024
      t.boolean :sent, :default => false
      t.boolean :accepted, :default => false
      t.timestamps
    end

  [:user_id, :email_address, :tid].each do |col|
    add_index :notification_invites, col
  end
  
  end

  def self.down
    drop_table :notification_invites
  end
end
