class PlaylistItemNotes < ActiveRecord::Migration
  def self.up
    add_column :playlist_items, :notes, :text
    add_column :playlist_items, :public_notes, :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :playlist_items, :notes
    remove_column :playlist_items, :public_notes
  end
end
