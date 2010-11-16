require 'migration_helpers'
class PlaylistAncestry < ActiveRecord::Migration
  extend MigrationHelpers
  def self.up

    [:playlists, :playlist_items ].each do|table|
      add_column table, :ancestry, :string
      add_index table, :ancestry
    end

    add_column :playlists, :position, :integer
    add_index :playlists, :position
    add_index :playlist_items, :position

    [:children_count, :ancestors_count, :descendants_count].each do |col|
      remove_column :playlist_items, col
    end

    PlaylistItem.build_ancestry_from_parent_ids!
    PlaylistItem.check_ancestry_integrity!
    # so - we're moving the tree that articulates the hierarchy within a playlist
    # into ancestry - but we're going to keep parent_id so we can track a playlist item's
    # when it's a copy. Position is used along with ancestry, NOT with lineage tracking.
    remove_column :playlist_items, :parent_id

    add_column :playlist_items, :playlist_item_parent_id, :integer
    add_index :playlist_items, :playlist_item_parent_id

    pint = 1
    Playlist.reset_column_information
    Playlist.find(:all, :order => 'title').each do |pl|
      pl.position = pint
      pl.save
      pint += 1
    end

  end

  def self.down
    add_column :playlist_items, :parent_id, :integer
    add_column :playlist_items, :children_count, :integer
    add_column :playlist_items, :ancestors_count, :integer
    add_column :playlist_items, :descendants_count, :integer
#    add_column :playlist_items, :position, :integer
    add_column :playlist_items, :hidden, :boolean
    create_acts_as_category_indexes(PlaylistItem)
    #this is not going to retain ancestry, so don't do it. Just here for thoroughness
    remove_column :playlists, :ancestry
    remove_column :playlist_items, :ancestry
  end
end
