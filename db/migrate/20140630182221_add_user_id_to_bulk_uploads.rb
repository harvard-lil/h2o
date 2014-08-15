class AddUserIdToBulkUploads < ActiveRecord::Migration
  def change
    add_column :bulk_uploads, :user_id, :integer, :null => false, :default => 0
  end
end
