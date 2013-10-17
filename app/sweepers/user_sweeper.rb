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
    if record.changed.include?("attribution")
      items = []
      [:playlists, :cases, :collages, :medias, :text_blocks].each do |t|
        set = record.send(t)
        items << set 
        set.each do |obj|
          expire_fragment "#{t.to_s.singularize}-list-object-#{obj.id}"
        end
      end
      Sunspot.index items
      Sunspot.commit
    end
  end
end
