class CreateImports < ActiveRecord::Migration
  def self.up
    create_table :imports do |t|
      t.integer :bulk_upload_id
      t.integer :actual_object_id
      t.integer :actual_object_type
      t.string :dropbox_filepath
      t.timestamps
    end
  end

  def self.down
    drop_table :imports
  end
end
