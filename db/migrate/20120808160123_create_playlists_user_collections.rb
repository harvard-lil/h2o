class CreatePlaylistsUserCollections < ActiveRecord::Migration
  def self.up
    create_table :playlists_user_collections, :id => false, :force => true do |t|
      t.references :playlist
      t.references :user_collection
    end
  end

  def self.down
    drop_table :playlists_user_collections
  end
end
