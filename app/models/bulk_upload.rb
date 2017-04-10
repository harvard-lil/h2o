# == Schema Information
#
# Table name: bulk_uploads
#
#  id             :integer          not null, primary key
#  created_at     :datetime
#  updated_at     :datetime
#  has_errors     :boolean
#  delayed_job_id :integer
#  user_id        :integer          default(0), not null
#

class BulkUpload < ApplicationRecord
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
