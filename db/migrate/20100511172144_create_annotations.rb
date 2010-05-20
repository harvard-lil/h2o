require 'migration_helpers'
class CreateAnnotations < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    create_table :annotations do |t|
      t.references :user
      t.references :collage
      t.string :annotation,             :limit => 10.kilobytes
      t.string :anchor_x_path,          :limit => 1.kilobytes 
      t.integer :anchor_sibling_offset
      t.integer :anchor_offset
      t.string :focus_x_path,           :limit => 1.kilobytes
      t.integer :focus_sibling_offset
      t.integer :focus_offset
      t.integer :parent_id
      t.integer :children_count
      t.integer :ancestors_count
      t.integer :descendants_count
      t.integer :position
      t.boolean :hidden
      t.timestamps
    end
    create_foreign_key(Annotation,Collage)
    create_foreign_key(Annotation,User)
    create_acts_as_category_indexes(Annotation)
  end

  def self.down
    drop_table :annotations
  end
end
