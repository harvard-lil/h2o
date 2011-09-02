require 'sweeper_helper'
class ItemBaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe ItemCollage, ItemCase, ItemPlaylist, ItemAnnotation, ItemQuestion, ItemQuestionInstance, ItemTextBlock, ItemDefault

  def clear_playlists(playlist)
    expire_page :controller => :playlists, :action => :show, :id => playlist.id
    expire_page :controller => :playlists, :action => :export, :id => playlist.id

    playlist.relation_ids.each do |p|
      expire_page :controller => :playlists, :action => :show, :id => p
      expire_page :controller => :playlists, :action => :export, :id => p
    end
  end

  def after_create(record)
    if params && params.has_key?(:container_id)
      playlist = Playlist.find(params[:container_id])
      clear_playlists(playlist)
    end
  end

  def after_update(record)
    if record && record.playlist_item
      clear_playlists(record.playlist_item.playlist)
    end
  end

  def before_destroy(record)
    if record && record.playlist_item
      clear_playlists(record.playlist_item.playlist)
    end
  end
end
