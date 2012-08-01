class CreateItemMedias < ActiveRecord::Migration
  def self.up
    create_table :item_medias do |t|
      t.string :title
      t.string :name
      t.string :url, :limit => 1024
      t.text :description
      t.string :actual_object_type
      t.integer :actual_object_id
      t.boolean :active, :default => true
      t.boolean :public, :default => true

      t.timestamps
    end
    [:active, :public, :url].each do |col|
      add_index :item_medias, col
    end
  end

  def self.down
    drop_table :item_medias
  end
end
