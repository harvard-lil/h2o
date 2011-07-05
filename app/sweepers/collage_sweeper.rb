require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def after_save(record)
    # Changing a case shouldn't effect where annotations are located. 
    # expire_fragment("collage-annotatable-content-#{record.id}")
	expire_fragment "collage-all-tags"
	expire_fragment "collage-#{record.id}-index"
	expire_fragment "collage-#{record.id}-tags"
	expire_fragment "collage-#{record.id}-meta"
	expire_fragment "case-#{record.annotatable_id}-index"

    #expire fragments of my ancestors, descendants, and siblings meta
    relations = [record.path_ids, record.descendant_ids, record.sibling_ids].flatten.uniq
	relations.each do |rel_id|
	  expire_fragment "collage-#{rel_id}-meta"
	end
  end

  def before_destroy(record)
	expire_fragment "collage-all-tags"
	expire_fragment "collage-#{record.id}-index"
	expire_fragment "collage-#{record.id}-tags"
	expire_fragment "collage-#{record.id}-meta"
	expire_fragment "case-#{record.annotatable_id}-index"

    #expire fragments of my ancestors, descendants, and siblings meta
    relations = [record.path_ids, record.descendant_ids, record.sibling_ids].flatten.uniq
	relations.each do |rel_id|
	  expire_fragment "collage-#{rel_id}-meta"
	end
  end
end
