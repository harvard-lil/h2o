class AddBookmarkIdToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :bookmark_id, :integer
  end

  def self.down
    remove_column :users, :bookmark_id
  end
end
