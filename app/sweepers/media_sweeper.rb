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

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if b.user && ['owner', 'creator'].include?(b.name); arr }.uniq
    users.push(current_user.id) if current_user
    users.each { |u| Rails.cache.delete("user-medias-#{u}") }
  end

  def after_save(record)
    media_clear(record)
  end

  def before_destroy(record)
    media_clear(record)
  end
end
