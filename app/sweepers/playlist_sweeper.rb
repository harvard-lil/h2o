require 'sweeper_helper'
class PlaylistSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Playlist

  def playlist_clear(record, creation)
    begin
      Rails.cache.delete_matched(%r{playlists-embedded-search*})

      return if creation || record.changed.empty?
  
      expire_fragment "playlist-list-object-#{record.id}"
      expire_page :controller => :playlists, :action => :show, :id => record.id
      expire_page :controller => :playlists, :action => :export, :id => record.id
      Rails.cache.delete("playlist-wordcount-#{record.id}")
  
      record.path_ids.each do |parent_id|
        Rails.cache.delete("playlist-wordcount-#{parent_id}")
        Rails.cache.delete("playlist-barcode-#{parent_id}")
        Rails.cache.delete("views/playlist-barcode-html-#{parent_id}")
      end
      record.relation_ids.each do |p|
        Rails.cache.delete("playlist-wordcount-#{p}")
        Rails.cache.delete("playlist-barcode-#{p}")
        Rails.cache.delete("views/playlist-barcode-html-#{p}")
        expire_page :controller => :playlists, :action => :show, :id => p
        expire_page :controller => :playlists, :action => :export, :id => p
      end

      if record.changed.include?("public")
        #TODO: Move this into SweeperHelper, but right now doesn't call
        [:playlists, :collages, :cases].each do |type|
          record.user.send(type).each { |i| expire_page :controller => type, :action => :show, :id => i.id }
        end
        Rails.cache.delete("user-barcode-#{record.user_id}")
      end
    rescue Exception => e
      Rails.logger.warn "Playlist sweeper error: #{e.inspect}"
    end
  end

  def playlist_clear_nonsiblings(id)
    record = Playlist.find(params[:id])

    expire_page :controller => :playlists, :action => :show, :id => record.id
    expire_page :controller => :playlists, :action => :export, :id => record.id

    record.relation_ids.each do |p|
      expire_page :controller => :playlists, :action => :show, :id => p
      expire_page :controller => :playlists, :action => :export, :id => p
    end
  end

  def after_create(record)
    playlist_clear(record, true)
  end

  def after_update(record)
    playlist_clear(record, false)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items_as_actual_object)
    playlist_clear(record, false)
  end

  def after_playlists_position_update
    playlist_clear_nonsiblings(params[:id])
  end

  def after_playlists_notes
    playlist_clear_nonsiblings(params[:id])
  end
end
