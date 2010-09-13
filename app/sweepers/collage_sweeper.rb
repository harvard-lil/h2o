require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def after_save(record)
    # Changing a case shouldn't effect where annotations are located. 
    # expire_fragment("collage-annotatable-content-#{record.id}")
    expire_fragment("collage-index-view-#{record.id}")
    expire_fragment("collage-show-meta-#{record.id}")
  end

  def before_destroy(record)
    # Probably not really needed, but whatever.
    expire_fragment("collage-annotatable-content-#{record.id}")
    expire_fragment("collage-index-view-#{record.id}")
    expire_fragment("collage-show-meta-#{record.id}")
  end

end
