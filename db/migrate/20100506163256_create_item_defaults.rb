class CreateItemDefaults < ActiveRecord::Migration
  def self.up
    create_table :item_defaults do |t|
      t.string  :title
      t.string  :output_text,   :limit => 1024
      t.string  :url,   :limit => 1024
      t.text    :description
      t.boolean :active, :default => true
      t.timestamps
    end

    [:active, :url].each do |col|
      add_index :item_defaults, col
    end
  end

  def self.down
    drop_table :item_defaults
  end
end
