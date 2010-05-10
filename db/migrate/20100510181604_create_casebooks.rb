class CreateCasebooks < ActiveRecord::Migration
  def self.up
    create_table :casebooks do |t|
      t.references :user
      t.string :name, :limit => 250
      t.string :description, :limit => 64.kilobytes
      t.integer :parent_id
      t.integer :children_count
      t.integer :ancestors_count
      t.integer :descendants_count
      t.integer :position
      t.boolean :hidden
      t.timestamps
    end

    [:parent_id, :children_count, :ancestors_count, :descendants_count, :position, :hidden].each do |col|
      add_index :casebooks, col
    end
  end

  def self.down
    drop_table :casebooks
  end
end
