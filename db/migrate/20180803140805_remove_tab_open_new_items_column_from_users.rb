class RemoveTabOpenNewItemsColumnFromUsers < ActiveRecord::Migration[5.1]
  def change
    remove_column :users, :tab_open_new_items, :boolean
  end
end
