class BulkUpload < ActiveRecord::Base
  has_many :imports
  has_many :error_imports, -> { where status: 'Errored' }, class_name: "Import"
  has_many :dupe_imports, -> { where status: 'Dupe Detected' }, class_name: "Import"
  has_many :successful_imports, -> { where status: 'Object Created' }, class_name: "Import"

  def name
    @page_title = "Bulk Upload"
  end

  # For check authorization
  def public?
    false
  end

  # TODO: Add link to user later
  def user
    1
  end
end
