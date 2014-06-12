require 'sweeper_helper'
class MediaSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Media

  def media_clear(record)
    begin
      Rails.cache.delete_matched(%r{medias-search*})
      Rails.cache.delete_matched(%r{medias-embedded-search*})
  
      ActionController::Base.new.expire_fragment "media-#{record.id}-tags"
      ActionController::Base.new.expire_fragment "media-list-object-#{record.id}"

      if record.changed.include?("public")
        [:playlists, :collages, :cases].each do |type|
          record.user.send(type).each { |i| ActionController::Base.expire_page "/#{type.to_s}/#{i.id}.html" }
        end
        # Rails.cache.delete("user-barcode-#{record.user_id}")
      end
    rescue Exception => e
      Rails.logger.warn "Media sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    # FIXME
    # Note: For some reason, this is being triggered by base#embedded_pager, so this should skip it
    # return if params && params[:action] == "embedded_pager"

    media_clear(record)
    notify_private(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    media_clear(record)
  end
end
