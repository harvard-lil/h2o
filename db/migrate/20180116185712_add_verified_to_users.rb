class AddVerifiedToUsers < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :verified_professor, :boolean, index: true, default: false
    add_column :users, :professor_verification_requested, :boolean, index: true, default: false
  end

  def down
    remove_column :users, :verified_professor, :boolean, index: true, default: false
    remove_column :users, :professor_verification_requested, :boolean, index: true, default: false
  end
end
