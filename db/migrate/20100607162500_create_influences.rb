class CreateInfluences < ActiveRecord::Migration
  def self.up
    create_table :influences do |t|
      t.integer :resource_id
      t.string :resource_type
      t.integer :parent_id, :children_count, :ancestors_count, :descendants_count
      t.boolean :hidden
      t.integer :position
      t.timestamps
    end

    [:resource_id, :resource_type, :parent_id, :children_count, :ancestors_count, :descendants_count].each do |col|
      add_index :influences, col
    end
  end

  def self.down
    drop_table :influences
  end
end
