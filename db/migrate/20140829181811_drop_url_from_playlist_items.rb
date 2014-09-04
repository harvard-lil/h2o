class DropUrlFromPlaylistItems < ActiveRecord::Migration
  def change
    remove_column :playlist_items, :url
  end
end
