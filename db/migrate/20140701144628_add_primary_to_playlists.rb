class AddPrimaryToPlaylists < ActiveRecord::Migration
  def change
    add_column :playlists, :primary, :boolean, :null => false, :default => false
  end
end
