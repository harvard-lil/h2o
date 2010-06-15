require 'sweeper_helper'
class AnnotationSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  
  observe Annotation

  def after_save(record)
    expire_fragment("annotation-annotated-content-#{record.id}")
    expire_fragment("collage-annotable-content-#{record.collage.id}")
  end

  def before_destroy(record)
    expire_fragment("annotation-annotated-content-#{record.id}")
    expire_fragment("collage-annotable-content-#{record.collage.id}")
  end

end
