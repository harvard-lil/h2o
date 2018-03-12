class AddAncestryDepthToContentNodes < ActiveRecord::Migration[5.1]
  def change
    add_column :content_nodes, :ancestry_depth, :integer, :default => 0
  end
end
