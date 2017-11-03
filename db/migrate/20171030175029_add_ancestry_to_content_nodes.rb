class AddAncestryToContentNodes < ActiveRecord::Migration[5.1]
  def change 
    add_column :content_nodes, :ancestry, :string, index: true
  end
end
