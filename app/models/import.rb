class Import < ActiveRecord::Base
  belongs_to :bulk_upload
  belongs_to :actual_object, :polymorphic => true

  def created_object
    if self.status == "Object Created"
      self.actual_object
    else
      Import.find(:first, :conditions => "imports.dropbox_filepath = '#{self.dropbox_filepath}' AND status = 'Object Created'").actual_object
    end
  end

  def self.completed_paths(klass)
    pg_result = ActiveRecord::Base.connection.execute("SELECT DISTINCT i.dropbox_filepath
                                                       FROM imports i
                                                       WHERE i.actual_object_type = '#{klass.to_s}'
                                                       AND i.status = 'Object Created';")
    pg_result.values.compact.flatten
  end
end
