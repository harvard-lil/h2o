class CreateAnnotations < ActiveRecord::Migration
  def self.up
    create_table :annotations do |t|
      t.integer :collage_id
      t.integer :user_id
      t.string :dom_element
      t.string :annotation
      t.integer :parent_id
      t.integer :children_count
      t.integer :ancestors_count
      t.integer :descendants_count
      t.integer :position
      t.boolean :hidden

      t.timestamps
    end
  end

  def self.down
    drop_table :annotations
  end
end
