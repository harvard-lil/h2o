class AddPerishableTokenToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :perishable_token, :string
  end

  def self.down
    remove_column :users, :perishable_token
  end
end
