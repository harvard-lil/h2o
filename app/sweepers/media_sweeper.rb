require 'sweeper_helper'
class MediaSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Media

  def media_clear(record)
    begin
      if record.changed.include?("public")
        [:playlists, :collages, :cases].each do |type|
          record.user.send(type).each { |i| ActionController::Base.expire_page "/#{type.to_s}/#{i.id}.html" }
          record.user.send(type).each { |i| ActionController::Base.expire_page "/iframe/load/#{type.to_s}/#{i.id}.html" }
          record.user.send(type).each { |i| ActionController::Base.expire_page "/iframe/show/#{type.to_s}/#{i.id}.html" }
        end
      end
    rescue Exception => e
      Rails.logger.warn "Media sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    media_clear(record)
    notify_private(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    media_clear(record)
  end
end
