require 'sweeper_helper'
class PlaylistItemSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe PlaylistItem

  def after_create(record)
    return if record.playlist && record.playlist.name == "Your Bookmarks"
    clear_playlists([record])
  end

  def after_update(record)
    clear_playlists([record])
  end

  def before_destroy(record)
    return if record.playlist && record.playlist.name == "Your Bookmarks"
    clear_playlists([record])
  end
end
