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

  end

  def self.down
    drop_table :item_defaults
  end
end
