require 'sweeper_helper'
class AnnotationSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  
  observe Annotation

  def collage_clear(record)
    ActionController::Base.expire_page "/collages/#{record.collage.id}.html"
    Rails.logger.debug("Sweeper: #{record.collage.id}")
    ActionController::Base.expire_page "/iframe/load/collages/#{record.collage.id}.html"
    ActionController::Base.expire_page "/iframe/show/collages/#{record.collage.id}.html"
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
