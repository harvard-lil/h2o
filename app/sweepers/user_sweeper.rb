require 'sweeper_helper'
class UserSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe User

  def after_users_delete_bookmark_item
    if current_user
      Rails.cache.delete("user-bookmarks-#{current_user.id}")
      Rails.cache.delete("user-bookmarks-map-#{current_user.id}")
    end
  end

  def after_users_bookmark_item
    if current_user
      Rails.cache.delete("user-bookmarks-#{current_user.id}")
      Rails.cache.delete("user-bookmarks-map-#{current_user.id}")
    end
  end

  def after_update(record)
    if record.saved_changes.keys.include?("attribution")
      record.collages.each do |collage|
        ActionController::Base.expire_page "/collages/#{collage.id}.html"
      end
      record.playlists.each do |playlist|
        ActionController::Base.expire_page "/playlists/#{playlist.id}.html"
        ActionController::Base.expire_page "/playlists/#{playlist.id}/export.html"
      end

      Sunspot.index record.all_items
      Sunspot.commit
    end

    if record.saved_changes.keys.include?("description")
      record.playlists.each {|playlist| playlist.clear_page_cache}
    end
  end
end
