require 'sweeper_helper'
class PlaylistSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Playlist

  def playlist_clear(record, creation)
    begin
      return if creation || record.changed.empty?
  
      ActionController::Base.expire_page "/playlists/#{record.id}.html"
      ActionController::Base.expire_page "/playlists/#{record.id}/export.html"
  
      record.relation_ids.each do |p|
        ActionController::Base.expire_page "/playlists/#{p}.html"
        ActionController::Base.expire_page "/playlists/#{p}/export.html"
      end

      if record.changed.include?("public")
        [:playlists, :collages, :cases].each do |type|
          record.user.send(type).each { |i| ActionController::Base.expire_page "/#{type.to_s}/#{i.id}.html" }
        end
      end
    rescue Exception => e
      Rails.logger.warn "Playlist sweeper error: #{e.inspect}"
    end
  end

  def after_create(record)
    playlist_clear(record, true)
  end

  def after_update(record)
    return true if record.changed.include?("karma")

    playlist_clear(record, false)
    notify_private(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items_as_actual_object)
    playlist_clear(record, false)
  end

  def after_playlists_notes
    Playlist.clear_nonsiblings(params[:id])
  end
end
