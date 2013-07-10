require 'sweeper_helper'
class MediaSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Media

  def media_clear(record)
    begin
      expire_page :controller => :medias, :action => :show, :id => record.id
  
      Rails.cache.delete_matched(%r{medias-search*})
      Rails.cache.delete_matched(%r{medias-embedded-search*})
  
      expire_fragment "media-all-tags"
      expire_fragment "media-#{record.id}-index"
      expire_fragment "media-#{record.id}-tags"
      expire_fragment "media-#{record.id}-annotatable-content"

      users = (record.owners + record.creators).uniq
      if record.changed.include?("public")
        users.each do |u|
          #TODO: Move this into SweeperHelper, but right now doesn't call
          [:playlists, :collages, :cases].each do |type|
            u.send(type).each { |i| expire_page :controller => type, :action => :show, :id => i.id }
          end
          Rails.cache.delete("user-barcode-#{u.id}")
        end
      end
      users.each { |u| Rails.cache.delete("user-medias-#{u.id}") }
    rescue Exception => e
      Rails.logger.warn "Media sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    media_clear(record)
  end

  def before_destroy(record)
    media_clear(record)
  end
end
