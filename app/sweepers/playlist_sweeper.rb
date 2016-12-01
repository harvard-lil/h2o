require 'sweeper_helper'
class PlaylistSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Playlist

  def playlist_clear(record, creation)
    return if creation || record.changed.empty?
    record.clear_page_cache
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
