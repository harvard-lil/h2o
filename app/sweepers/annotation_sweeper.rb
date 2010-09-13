require 'sweeper_helper'
class AnnotationSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  
  observe Annotation

  def after_save(record)
    expire_fragment("collage-annotatable-content-#{record.collage.id}")
    expire_fragment("collage-index-view-#{record.collage.id}")
    expire_fragment("collage-show-meta-#{record.collage.id}")
  end

  def after_create(record)
    # We are adding a new annotation and must therefore regenerate annotation decorations.
    expire_fragment("collage-annotatable-content-#{record.collage.id}")
    expire_fragment("collage-index-view-#{record.collage.id}")
    expire_fragment("collage-show-meta-#{record.collage.id}")
  end

  def after_destroy(record)
    # We are removing an annotation and must remove it from annotation decorations.
    expire_fragment("collage-annotatable-content-#{record.collage.id}")
    expire_fragment("collage-index-view-#{record.collage.id}")
    expire_fragment("collage-show-meta-#{record.collage.id}")
  end

end
