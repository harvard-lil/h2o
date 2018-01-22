class AddVerifiedToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :verified_professor, :boolean, index: true, default: false
    add_column :users, :professor_verification_requested, :boolean, index: true, default: false
  end
end
