class BulkUpload < ActiveRecord::Base
  has_many :imports
  has_many :error_imports, -> { where status: 'Errored' }, class_name: "Import"
  has_many :dupe_imports, -> { where status: 'Dupe Detected' }, class_name: "Import"
  has_many :successful_imports, -> { where status: 'Object Created' }, class_name: "Import"
  belongs_to :user

  validates_presence_of :user

  def name
    @page_title = "Bulk Upload"
  end

  # For check authorization
  def public?
    false
  end
end
