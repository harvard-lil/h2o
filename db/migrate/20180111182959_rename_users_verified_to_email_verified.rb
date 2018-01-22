class RenameUsersVerifiedToEmailVerified < ActiveRecord::Migration[5.1]
  def change
    rename_column :users, :verified, :verified_email
  end
end
