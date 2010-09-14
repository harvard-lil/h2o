require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def after_save(record)
    # Changing a case shouldn't effect where annotations are located. 
    # expire_fragment("collage-annotatable-content-#{record.id}")
    expire_fragment("collage-index-view-#{record.id}")
    expire_fragment("collage-show-layer-controls-#{record.id}")
    expire_fragment("collage-meta-#{record.id}")

    #expire fragments of my ancestors to ensure we don't emit non-existent collages
    record.path_ids.each do |path_id|
      expire_fragment("collage-index-view-#{path_id}")
      expire_fragment("collage-show-layer-controls-#{path_id}")
      expire_fragment("collage-meta-#{path_id}")
    end
    #expire fragments of my descendants too. . .
    record.descendant_ids.each do |descendant_id|
      expire_fragment("collage-index-view-#{descendant_id}")
      expire_fragment("collage-show-layer-controls-#{descendant_id}")
      expire_fragment("collage-meta-#{descendant_id}")
    end
    # and finally, my siblings
    record.sibling_ids.each do |sibling_id|
      expire_fragment("collage-index-view-#{sibling_id}")
      expire_fragment("collage-show-layer-controls-#{sibling_id}")
      expire_fragment("collage-meta-#{sibling_id}")
    end

  end

  def before_destroy(record)
    expire_fragment("collage-annotatable-content-#{record.id}")
    expire_fragment("collage-index-view-#{record.id}")
    expire_fragment("collage-show-meta-#{record.id}")

    #expire fragments of my ancestors to ensure we don't emit non-existent collages
    record.path_ids.each do |path_id|
      expire_fragment("collage-index-view-#{path_id}")
      expire_fragment("collage-show-meta-#{path_id}")
    end
    #expire fragments of my descendants too. . .
    record.descendant_ids.each do |descendant_id|
      expire_fragment("collage-index-view-#{descendant_id}")
      expire_fragment("collage-show-meta-#{descendant_id}")
    end
    # and finally, my siblings
    record.sibling_ids.each do |sibling_id|
      expire_fragment("collage-index-view-#{sibling_id}")
      expire_fragment("collage-show-meta-#{sibling_id}")
    end

  end

end
