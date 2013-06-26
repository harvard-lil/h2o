class Import < ActiveRecord::Base
  belongs_to :bulk_upload
  belongs_to :actual_object, :polymorphic => true

  def full_name
    self.get_attr(:full_name)
  end

  def short_name
    self.get_attr(:short_name)
  end

  def active?
    get_attr(:active?)
  end
  def get_attr(attr)
    unless self.created_object.nil?
      self.created_object.send(attr)
    end
  end

  def created_object
    if self.status == "Object Created"
      self.actual_object
    else
      Import.find(:first,
                  :conditions => ["imports.dropbox_filepath = ?
                                  AND status = 'Object Created'", self.dropbox_filepath]).actual_object
    end
  end

  def self.completed_paths(klass)
    imports = Import.find :all, :conditions => ["actual_object_type = ? AND status = ?",
                                                klass.to_s, 'Object Created']
    imports = imports.map(&:dropbox_filepath).uniq.compact.flatten
    imports
  end
end
