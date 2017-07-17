class AddIndexesToUsers < ActiveRecord::Migration[5.1]
  def change
    add_index :users, :id
    add_index :users, :attribution
    add_index :users, :affiliation
  end
end
