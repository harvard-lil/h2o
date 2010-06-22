require 'migration_helpers'
class CreateCollages < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    create_table :collages do |t|
      t.string :annotatable_type
      t.integer :annotatable_id
      t.string :name, :limit => 250, :null => false
      t.string :description, :limit => 5.kilobytes
      t.integer :parent_id
      t.integer :children_count
      t.integer :ancestors_count
      t.integer :descendants_count
      t.integer :position
      t.boolean :hidden
      if connection.adapter_name.downcase == 'postgresql'
        t.string  :content,           :limit => 5.megabytes,  :null => false
      else
        t.text    :content,           :limit => 5.megabytes,  :null => false
      end
      t.timestamps
    end
    create_acts_as_category_indexes(Collage)
    [:annotatable_type, :annotatable_id, :name, :updated_at, :created_at].each do |col|
      add_index :collages, col
    end
  end

  def self.down
    drop_table :collages
  end
end
