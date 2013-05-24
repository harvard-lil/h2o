class AddHasErrorsToBulkUpload < ActiveRecord::Migration
  def self.up
    add_column :bulk_uploads, :has_errors, :boolean
  end

  def self.down
    remove_column :bulk_uploads, :has_errors
  end
end