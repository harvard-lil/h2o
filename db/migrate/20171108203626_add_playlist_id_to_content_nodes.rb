class AddPlaylistIdToContentNodes < ActiveRecord::Migration[5.1]
  def change
    add_column :content_nodes, :playlist_id, :bigint, index: true
  end
end
