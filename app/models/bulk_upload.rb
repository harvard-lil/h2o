class BulkUpload < ActiveRecord::Base
  has_many :imports
end
