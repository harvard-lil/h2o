require 'sweeper_helper'
class MediaSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Media

  def media_clear(record)
    begin
      expire_page :controller => :medias, :action => :show, :id => record.id
  
      Rails.cache.delete_matched(%r{medias-search*})
      Rails.cache.delete_matched(%r{medias-embedded-search*})
  
      expire_fragment "media-#{record.id}-tags"
      expire_fragment "media-list-object-#{record.id}"

      if record.changed.include?("public")
        #TODO: Move this into SweeperHelper, but right now doesn't call
        [:playlists, :collages, :cases].each do |type|
          record.user.send(type).each { |i| expire_page :controller => type, :action => :show, :id => i.id }
        end
        Rails.cache.delete("user-barcode-#{record.user_id}")
      end
    rescue Exception => e
      Rails.logger.warn "Media sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    # Note: For some reason, this is being triggered by base#embedded_pager, so this should skip it
    return if params && params[:action] == "embedded_pager"

    media_clear(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    media_clear(record)
  end
end
