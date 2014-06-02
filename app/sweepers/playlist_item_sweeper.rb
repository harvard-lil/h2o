require 'sweeper_helper'
class PlaylistItemSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe PlaylistItem

  def actual_object_clear(actual_object)
    begin
      if actual_object.present?
        Rails.cache.delete("#{actual_object.class.to_s.downcase}-barcode-#{actual_object.id}")
        Rails.cache.delete("views/#{actual_object.class.to_s.downcase}-barcode-html-#{actual_object.id}")
        if [Playlist, Collage, Case].include?(actual_object.class)
          ActionController::Base.expire_page "/#{actual_object.class.to_s.tableize}/#{actual_object.id}.html"
          ActionController::Base.expire_page "/#{actual_object.class.to_s.tableize}/#{actual_object.id}/export.html"
        end
      end
    rescue Exception => e
      Rails.logger.warn "Playlist item sweeper error: #{e.inspect}"
    end
  end

  def after_create(record)
    clear_playlists([record])
    actual_object_clear(record.actual_object)
  end

  def after_update(record)
    clear_playlists([record])
  end

  def before_destroy(record)
    clear_playlists([record])
    actual_object_clear(record.actual_object)
  end
end
