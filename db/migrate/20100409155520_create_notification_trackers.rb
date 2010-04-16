class CreateNotificationTrackers < ActiveRecord::Migration
  def self.up
    create_table :notification_trackers do |t|
      t.integer  :rotisserie_discussion_id
      t.integer  :rotisserie_post_id
      t.integer  :user_id
      t.string   :notify_description
      t.timestamps
    end

    [:rotisserie_discussion_id, :rotisserie_post_id, :user_id].each do |col|
      add_index :notification_trackers, col
    end
  end

  def self.down
    drop_table :notification_trackers
  end
end
