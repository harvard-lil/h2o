class RemameVerifiedEmailVariable < ActiveRecord::Migration[5.1]
  def change
    rename_column :users, :verified_email, :email_confirmed
  end
end
