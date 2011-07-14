require 'sweeper_helper'
class AnnotationSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  
  observe Annotation

  def collage_clear(record)
    expire_page :controller => :collages, :action => :show, :id => record.collage.id
    expire_fragment "collage-#{record.collage.id}-annotatable-content"
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
