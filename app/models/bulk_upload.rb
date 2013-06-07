class BulkUpload < ActiveRecord::Base
  has_many :imports
  has_many :error_imports, :conditions => "imports.status = 'Errored'", :class_name => "Import"
  has_many :dupe_imports, :conditions => "imports.status = 'Dupe Detected'", :class_name => "Import"
  has_many :successful_imports, :conditions => "imports.status = 'Object Created'", :class_name => "Import"


end
