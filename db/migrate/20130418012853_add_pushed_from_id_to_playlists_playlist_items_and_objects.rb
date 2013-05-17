class AddPushedFromIdToPlaylistsPlaylistItemsAndObjects < ActiveRecord::Migration
  def self.up
    add_column :collages, :pushed_from_id, :integer
    add_column :annotations, :pushed_from_id, :integer
    add_column :cases, :pushed_from_id, :integer
    add_column :medias, :pushed_from_id, :integer
    add_column :playlists, :pushed_from_id, :integer
    add_column :questions, :pushed_from_id, :integer
    add_column :question_instances, :pushed_from_id, :integer
    add_column :rotisserie_discussions, :pushed_from_id, :integer
    add_column :text_blocks, :pushed_from_id, :integer
    add_column :playlist_items, :pushed_from_id, :integer
  end

  def self.down
    remove_column :playlist_items, :pushed_from_id
    remove_column :text_blocks, :pushed_from_id
    remove_column :rotisserie_discussions, :pushed_from_id
    remove_column :question_instances, :pushed_from_id
    remove_column :questions, :pushed_from_id
    remove_column :playlists, :pushed_from_id
    remove_column :medias, :pushed_from_id
    remove_column :cases, :pushed_from_id
    remove_column :annotations, :pushed_from_id
    remove_column :collages, :pushed_from_id
  end
end