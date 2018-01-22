class AddProfessorVerificationSentToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :professor_verification_sent, :boolean, index: true, default: false
  end
end
