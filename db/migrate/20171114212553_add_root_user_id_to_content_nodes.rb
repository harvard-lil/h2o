class AddRootUserIdToContentNodes < ActiveRecord::Migration[5.1]
  def change
    add_column :content_nodes, :root_user_id, :bigint, index: true
  end
end
