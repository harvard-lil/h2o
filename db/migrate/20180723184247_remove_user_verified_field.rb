class RemoveUserVerifiedField < ActiveRecord::Migration[5.1]
  def change
    remove_column :users, :verified_email
  end
end
