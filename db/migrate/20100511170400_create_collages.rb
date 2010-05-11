class CreateCollages < ActiveRecord::Migration
  def self.up
    create_table :collages do |t|
      t.integer :user_id
      t.string :annotatable_type
      t.integer :annotatable_id
      t.string :name
      t.text :description
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
    drop_table :collages
  end
end
