require 'sweeper_helper'
class PlaylistItemSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe PlaylistItem

  def clear_playlists(playlist)
    if playlist.present?
      expire_page :controller => :playlists, :action => :show, :id => playlist.id
      expire_page :controller => :playlists, :action => :export, :id => playlist.id
      Rails.cache.delete("playlist-wordcount-#{playlist.id}")
    end
  end

  def actual_object_clear(actual_object)
    begin

      if actual_object.present?
        Rails.cache.delete("#{actual_object.class.to_s.downcase}-barcode-#{actual_object.id}")
        Rails.cache.delete("views/#{actual_object.class.to_s.downcase}-barcode-html-#{actual_object.id}")
        if [Playlist, Collage, Case].include?(actual_object.class)
          expire_page :controller => actual_object.class.to_s.tableize.to_sym, :action => :show, :id => actual_object.id
        end
      end
    rescue Exception => e
      Rails.logger.warn "Playlist item sweeper error: #{e.inspect}"
    end
  end

  def after_create(record)
    clear_playlists(record.playlist)
    actual_object_clear(record.actual_object)
  end

  def after_update(record)
    clear_playlists(record.playlist)
  end

  def before_destroy(record)
    clear_playlists(record.playlist)
    actual_object_clear(record.actual_object)
  end
end
