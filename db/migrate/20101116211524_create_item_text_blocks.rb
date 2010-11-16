class CreateItemTextBlocks < ActiveRecord::Migration
  def self.up
    
    create_table :item_text_blocks do |t|
      t.string   :title
      t.string   :name,               :limit => 1024
      t.string   :url,                :limit => 1024
      t.text     :description
      t.boolean  :active,                             :default => true
      t.boolean  :public,                             :default => true
      t.string   :actual_object_type
      t.integer  :actual_object_id

      t.timestamps
    end
    
    [:active, :public, :url, :actual_object_type, :actual_object_id].each do |col|
      add_index :item_text_blocks, col
    end

  end

  def self.down
    drop_table :item_text_blocks
  end
end
