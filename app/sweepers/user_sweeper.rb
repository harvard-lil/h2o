class UserSweeper < ActionController::Caching::Sweeper
  observe User

  def after_update(record)
    if record.saved_changes.keys.include?("attribution")
      Sunspot.index record.text_blocks
      Sunspot.commit
    end
  end
end
