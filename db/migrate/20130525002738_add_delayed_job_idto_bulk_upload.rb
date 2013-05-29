class AddDelayedJobIdtoBulkUpload < ActiveRecord::Migration
  def self.up
    add_column :bulk_uploads, :delayed_job_id, :integer
  end

  def self.down
    remove_column :bulk_uploads, :delayed_job_id
  end
end