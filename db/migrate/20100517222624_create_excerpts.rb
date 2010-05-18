require 'migration_helpers'
class CreateExcerpts < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    create_table :excerpts do |t|
      t.references :user
      t.references :collage
      t.string :reason,             :limit => 10.kilobytes
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
    create_foreign_key(Excerpt,Collage)
    create_foreign_key(Excerpt,User)
    create_acts_as_category_indexes(Excerpt)
  end

  def self.down
    drop_table :excerpts
  end
end
