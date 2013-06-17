class AddViewPrivatePlaylistPermission < ActiveRecord::Migration
  def self.up
    Permission.create({ :key => 'view_private', :label => 'View Playlists (if private)', :permission_type => 'playlist' })
  end

  def self.down
  end
end
