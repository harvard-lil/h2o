class Import < ActiveRecord::Base
  belongs_to :bulk_upload
  belongs_to :actual_object, :polymorphic => true

  def created_object
    if self.status == "Object Created"
      self.actual_object
    else
      Import.find(:first, 
                  :conditions => "imports.dropbox_filepath = '#{self.dropbox_filepath}' 
                                  AND status = 'Object Created'").actual_object
    end
  end

  def self.completed_paths(klass)
    imports = Import.find :all, :conditions => ["actual_object_type = ? AND status = ?", 
                                                klass.to_s, 'Object Created']
    imports = imports.map(&:dropbox_filepath).uniq.compact.flatten
    imports
  end
end
