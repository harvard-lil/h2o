require 'sweeper_helper'
class PlaylistSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Playlist

  def after_save(record)
	expire_fragment "playlist-all-tags"
	expire_fragment "playlist-#{record.id}-index"
	expire_fragment "playlist-#{record.id}-tags"

	expire_fragment "user-playlists-#{current_user.id}"
  end

  def before_destroy(record)
	expire_fragment "playlist-all-tags"
	expire_fragment "playlist-#{record.id}-index"
	expire_fragment "playlist-#{record.id}-tags"

	expire_fragment "user-playlists-#{current_user.id}"
  end
end
