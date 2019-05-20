class RemoveBulkUploads < ActiveRecord::Migration[5.2]
  def up
    drop_table :bulk_uploads
  end

  def down
    create_table :bulk_uploads do |t|
      t.references :users, :null => false, :default => 0
      t.boolean :has_errors
      t.integer :delayed_job_id
      t.timestamps
    end
  end
end
