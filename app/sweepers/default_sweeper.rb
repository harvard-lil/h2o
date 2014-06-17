require 'sweeper_helper'
class DefaultSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Default

  def before_destroy(record)
    clear_playlists(record.playlist_items)
  end
end
