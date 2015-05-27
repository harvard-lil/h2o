class CreateFrozenItems < ActiveRecord::Migration
  def change
    create_table :frozen_items do |t|
      t.text :content
      t.integer :version, :null => false
      t.integer :item_id, :null => false
      t.string :item_type, :null => false
      t.timestamps
    end
         
    add_column :text_blocks, :version, :integer, :null => false, :default => 1
    add_column :collages, :version, :integer, :null => false, :default => 1
  end
end
