class RemoveBookmarkIdColumnFromUsers < ActiveRecord::Migration[5.1]
  def change
    remove_column :users, :bookmark_id, :integer
  end
end
