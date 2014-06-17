require 'sweeper_helper'
class CaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Case

  def clear_case(record)
    begin
      ActionController::Base.expire_page "/cases/#{record.id}.html"
    rescue Exception => e
      Rails.logger.warn "Case sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    clear_case(record)
    notify_private(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    clear_case(record)
  end
end
