class CreateBulkUploads < ActiveRecord::Migration
  def self.up
    create_table :bulk_uploads do |t|
      t.timestamps
    end
  end

  def self.down
    drop_table :bulk_uploads
  end
end
