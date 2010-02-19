class CreateRotisserieTrackers < ActiveRecord::Migration
  def self.up
    create_table :rotisserie_trackers do |t|
      t.integer  :rotisserie_discussion_id
      t.integer  :rotisserie_post_id
      t.integer  :user_id
      t.string   :notify_description
      
      t.timestamps
    end

    [:user_id, :rotisserie_discussion_id, :rotisserie_post_id].each do |col|
      add_index :rotisserie_trackers, col
    end

  end

  def self.down
    drop_table :rotisserie_trackers
  end
end
