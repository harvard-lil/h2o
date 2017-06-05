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
      Sunspot.index record.all_items
      Sunspot.commit
    end

    if record.saved_changes.keys.include?("description")
      record.playlists.each {|playlist| playlist.clear_page_cache}
    end
  end
end
