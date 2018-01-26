class RenameUsersVerifiedToEmailVerified < ActiveRecord::Migration[5.1]
  def up
    rename_column :users, :verified, :verified_email
  end

  def down
    rename_column :users, :verified_email, :verified
  end
end
