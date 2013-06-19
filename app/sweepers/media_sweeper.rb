require 'sweeper_helper'
class MediaSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Media

  def media_clear(record)
    expire_page :controller => :medias, :action => :show, :id => record.id

    Rails.cache.delete_matched(%r{medias-search*})
    Rails.cache.delete_matched(%r{medias-embedded-search*})

    expire_fragment "media-all-tags"
    expire_fragment "media-#{record.id}-index"
    expire_fragment "media-#{record.id}-tags"
    expire_fragment "media-#{record.id}-annotatable-content"

    begin
      users = (record.owners + record.creators).uniq.collect { |u| u.id }
      users.each { |u| Rails.cache.delete("user-medias-#{u}") }
      if record.changed.include?("public")
        users.each { |u| Rails.cache.delete("user-barcode-#{u}") }
      end
    rescue Exception => e
    end
  end

  def after_save(record)
    media_clear(record)
  end

  def before_destroy(record)
    media_clear(record)
  end
end
