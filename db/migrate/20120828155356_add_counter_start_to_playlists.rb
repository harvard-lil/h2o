class AddCounterStartToPlaylists < ActiveRecord::Migration
  def self.up
    add_column :playlists, :counter_start, :integer, :null => false, :default => 1
  end

  def self.down
    remove_column :playlists, :counter_start
  end
end
