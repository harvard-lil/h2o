class CreatePlaylistItems < ActiveRecord::Migration
  def self.up
    create_table :playlist_items do |t|
      t.integer :playlist_id
      t.integer :resource_item_id
      t.string :resource_item_type
      t.boolean :active, :default => true
      t.integer :parent_id, :children_count, :ancestors_count, :descendants_count, :position
      t.timestamps
    end

    [:resource_item_id, :resource_item_type, :active].each do |col|
      add_index :playlist_items, col
    end

  end

  def self.down
    drop_table :playlist_items
  end
end
