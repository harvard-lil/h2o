require 'sweeper_helper'
class ItemBaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe ItemCollage, ItemCase, ItemPlaylist, ItemAnnotation, ItemQuestion, ItemQuestionInstance, ItemTextBlock, ItemDefault

  def after_create(record)
    if params && params.has_key?(:container_id)
      expire_page :controller => :playlists, :action => :show, :id => params[:container_id]

      Playlist.find(params[:container_id]).relation_ids.each do |p|
        expire_page :controller => :playlists, :action => :show, :id => p
      end
    end
  end

  def after_update(record)
    if record && record.playlist_item
      expire_page :controller => :playlists, :action => :show, :id => record.playlist_item.playist_id

      record.playlist_item.playlist.relation_ids.each do |p|
        expire_page :controller => :playlists, :action => :show, :id => p
      end
    end
  end

  def before_destroy(record)
    if record && record.playlist_item
      expire_page :controller => :playlists, :action => :show, :id => record.playlist_item.playist_id

      record.playlist_item.playlist.relation_ids.each do |p|
        expire_page :controller => :playlists, :action => :show, :id => p
      end
    end
  end
end
