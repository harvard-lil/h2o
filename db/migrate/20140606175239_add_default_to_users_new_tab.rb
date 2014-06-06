class AddDefaultToUsersNewTab < ActiveRecord::Migration
  def change
    change_column :users, :tab_open_new_items, :boolean, :null => false, :default => false
  end
end
