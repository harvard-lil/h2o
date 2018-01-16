class UndoProfessorVerificationMigrations < ActiveRecord::Migration[5.1]
  def change
      rename_column :users, :verified_email, :verified
  end
end
