class RenameUserCollField < ActiveRecord::Migration
  def change
    rename_column :user_collections, :owner_id, :user_id
  end
end
