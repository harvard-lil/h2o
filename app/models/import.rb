class Import < ActiveRecord::Base
  belongs_to :bulk_upload
  belongs_to :actual_object, :polymorphic => true
  
  
  def self.completed_paths(klass)
    pg_result = ActiveRecord::Base.connection.execute("SELECT DISTINCT i.dropbox_filepath 
                                                       FROM imports i
                                                       WHERE i.actual_object_type = '#{klass.to_s}';")
    pg_result.values.compact.flatten
  end
end
