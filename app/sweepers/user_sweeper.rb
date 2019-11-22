require 'sweeper_helper'
class UserSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe User

  def after_update(record)
    if record.saved_changes.keys.include?("attribution")
      # Sunspot.index record.text_blocks
      # Sunspot.commit
    end
  end
end
