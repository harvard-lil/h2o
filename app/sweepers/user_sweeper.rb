require 'sweeper_helper'
class UserSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe User

  def after_users_bookmark_item
    #TODO: Investigate if there's a better way to retrieve record rather than use params
    if current_user
      Rails.cache.delete("user-bookmark-#{params[:type]}-#{current_user.id}")
      Rails.cache.delete("user-bookmarks-#{current_user.id}")
	end
  end
end
