require 'migration_helpers'
class CreateAnnotations < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up
    create_table :annotations do |t|
      t.references :user
      t.references :collage
      t.string :annotation,             :limit => 10.kilobytes
      t.string :annotation_start
      t.string :annotation_end
      t.integer :word_count
      t.string :annotated_content,      :limit => 1.megabyte
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
    [:annotation_start, :annotation_end].each do|col|
      add_index :annotations, col
    end
    create_acts_as_category_indexes(Annotation)
  end

  def self.down
    drop_table :annotations
  end
end
