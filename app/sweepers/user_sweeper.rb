require 'sweeper_helper'
class UserSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe User

  def after_users_delete_bookmark_item
    if current_user
      Rails.cache.delete("user-bookmarks-#{current_user.id}")
	  end
  end

  def after_users_bookmark_item
    if current_user
      Rails.cache.delete("user-bookmarks-#{current_user.id}")
	  end
  end
end
