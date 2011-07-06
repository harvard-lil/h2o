require 'sweeper_helper'
class PlaylistSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Playlist

  def after_save(record)
	expire_fragment "playlist-all-tags"
	expire_fragment "playlist-#{record.id}-index"
	expire_fragment "playlist-#{record.id}-tags"

	expire_fragment "user-playlists-#{current_user.id}"

	record.relation_ids.each do |p|
	  expire_fragment "playlist-block-#{p}-true"
	  expire_fragment "playlist-block-#{p}-false"
	end
  end

  def before_destroy(record)
	expire_fragment "playlist-all-tags"
	expire_fragment "playlist-#{record.id}-index"
	expire_fragment "playlist-#{record.id}-tags"

	expire_fragment "user-playlists-#{current_user.id}"

	record.relation_ids.each do |p|
	  expire_fragment "playlist-block-#{p}-true"
	  expire_fragment "playlist-block-#{p}-false"
	end
  end

  def after_playlists_position_update
	expire_fragment "playlist-block-#{params[:id]}-true"
	expire_fragment "playlist-block-#{params[:id]}-false"

	record.relation_ids.each do |p|
	  expire_fragment "playlist-block-#{p}-true"
	  expire_fragment "playlist-block-#{p}-false"
	end
  end
end
