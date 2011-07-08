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
	  expire_fragment "playlist-block-#{p}-anon"
	  expire_fragment "playlist-block-#{p}-editable"
	end

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['name', 'creator'].include?(b.name); arr }.uniq
	users.each do |u|
	  Rails.cache.delete("user-playlists-#{u}")
	end
  end

  def before_destroy(record)
	expire_fragment "playlist-all-tags"
	expire_fragment "playlist-#{record.id}-index"
	expire_fragment "playlist-#{record.id}-tags"

	expire_fragment "user-playlists-#{current_user.id}"

	record.relation_ids.each do |p|
	  expire_fragment "playlist-block-#{p}-anon"
	  expire_fragment "playlist-block-#{p}-editable"
	end

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['name', 'creator'].include?(b.name); arr }.uniq
	users.each do |u|
	  Rails.cache.delete("user-playlists-#{u}")
	end
  end

  def after_playlists_position_update
	expire_fragment "playlist-block-#{params[:id]}-anon"
	expire_fragment "playlist-block-#{params[:id]}-editable"

	record.relation_ids.each do |p|
	  expire_fragment "playlist-block-#{p}-anon"
	  expire_fragment "playlist-block-#{p}-editable"
	end
  end
end
