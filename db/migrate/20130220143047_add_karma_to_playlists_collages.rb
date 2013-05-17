class AddKarmaToPlaylistsCollages < ActiveRecord::Migration
  def self.up
    add_column :playlists, :karma, :integer
    add_column :collages, :karma, :integer
    add_column :text_blocks, :karma, :integer
    add_column :medias, :karma, :integer
    add_column :cases, :karma, :integer
  end

  def self.down
    remove_column :playlists, :karma
    remove_column :collages, :karma
    remove_column :text_blocks, :karma
    remove_column :medias, :karma
    remove_column :cases, :karma
  end
end
