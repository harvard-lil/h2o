class AddBackVerifiedEmailToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :verified_email, :boolean, default: false, null: false
  end
end
