require 'sweeper_helper'
class AnnotationSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  
  observe Annotation

  def collage_clear(record)
    if record.annotated_item_type == 'Collage'
      ActionController::Base.expire_page "/collages/#{record.annotated_item_id}.html"
      ActionController::Base.expire_page "/iframe/load/collages/#{record.annotated_item_id}.html"
      ActionController::Base.expire_page "/iframe/show/collages/#{record.annotated_item_id}.html"
      record.annotated_item.touch
    end
  end

  def after_save(record)
    collage_clear(record)
  end

  def after_create(record)
    collage_clear(record)
  end

  def before_destroy(record)
    collage_clear(record)
  end
end
