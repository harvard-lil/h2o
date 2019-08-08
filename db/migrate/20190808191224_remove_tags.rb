class RemoveTags < ActiveRecord::Migration[5.2]
  def up
    drop_table :tags 
  end

  def down
    create_table :tags do |t|
      t.string :name
      t.integer :taggings_count
      t.timestamps
    end

    add_index tags, :name
  end
end
