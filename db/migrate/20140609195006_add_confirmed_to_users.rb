class AddConfirmedToUsers < ActiveRecord::Migration
  def change
    add_column :users, :verified, :boolean, :null => false, :default => false

    connection.execute "UPDATE users SET verified = true WHERE email_address LIKE '%.edu'"
  end
end
