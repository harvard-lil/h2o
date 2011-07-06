require 'sweeper_helper'
class ItemBaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe ItemCollage, ItemCase, ItemPlaylist, ItemAnnotation, ItemQuestion, ItemQuestionInstance, ItemTextBlock, ItemDefault

  def after_create(record)
	expire_fragment "playlist-block-#{params[:container_id]}-true"
	expire_fragment "playlist-block-#{params[:container_id]}-false"

	Playlist.find(params[:container_id]).relation_ids.each do |p|
	  expire_fragment "playlist-block-#{p}-true"
	  expire_fragment "playlist-block-#{p}-false"
	end
  end

  def after_update(record)
    if record && record.playlist_item
	  expire_fragment "playlist-block-#{record.playlist_item.playlist_id}-true"
	  expire_fragment "playlist-block-#{record.playlist_item.playlist_id}-false"

	  record.playlist_item.playlist.relation_ids.each do |p|
	    expire_fragment "playlist-block-#{p}-true"
	    expire_fragment "playlist-block-#{p}-false"
	  end
	end
  end

  def before_destroy(record)
    if record && record.playlist_item
      playlist_id = record.playlist_item.playlist_id
	  expire_fragment "playlist-block-#{playlist_id}-true"
	  expire_fragment "playlist-block-#{playlist_id}-false"

	  record.playlist_item.playlist.relation_ids.each do |p|
	    expire_fragment "playlist-block-#{p}-true"
	    expire_fragment "playlist-block-#{p}-false"
	  end
	end
  end
end
