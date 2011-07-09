require 'sweeper_helper'
class AnnotationSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  
  observe Annotation

  def after_save(record)
    expire_fragment "collage-#{record.collage.id}-layers"
    expire_fragment "collage-#{record.collage.id}-annotatable-content"
	expire_fragment "collage-#{record.collage.id}-annotations"
  end

  def after_create(record)
    # We are adding a new annotation and must therefore regenerate annotation decorations.
    expire_fragment "collage-#{record.collage.id}-layers"
    expire_fragment "collage-#{record.collage.id}-annotatable-content"
	expire_fragment "collage-#{record.collage.id}-annotations"
  end

  def before_destroy(record)
    # We are removing an annotation and must remove it from annotation decorations.
    expire_fragment "collage-#{record.collage.id}-layers"
    expire_fragment "collage-#{record.collage.id}-annotatable-content"
    expire_fragment "collage-#{record.collage.id}-annotations"
  end
end
