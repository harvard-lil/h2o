class AddConfirmedAndActiveRecordsToUsers < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :confirmed, :boolean, default: false, null: false
    add_column :users, :active, :boolean, default: false, null: false
  end

  def down
    remove_column :users, :confirmed
    remove_column :users, :active
  end
end
