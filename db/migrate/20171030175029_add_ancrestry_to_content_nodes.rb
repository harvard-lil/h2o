class AddAncrestryToContentNodes < ActiveRecord::Migration[5.1]
  def change
    add_column :content_nodes, :ancestry, :string
    add_index :content_nodes, :ancestry
  end
end
