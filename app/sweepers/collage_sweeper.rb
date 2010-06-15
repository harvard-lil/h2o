require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def after_save(record)
    expire_fragment("collage-annotable-content-#{record.id}")
  end

  def before_destroy(record)
    expire_fragment("collage-annotable-content-#{record.id}")
  end

end
