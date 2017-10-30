class AddAncrestryToContentNodes < ActiveRecord::Migration[5.1]
  def up 
    add_column :content_nodes, :ancestry, :string
    add_index :content_nodes, :ancestry
  end

  def down
    remove_column :content_nodes, :ancestry
    remove_index :content_nodes, :ancestry
  end
end
