class CreateCasebookCollaborators < ActiveRecord::Migration[5.1]
  def change
    create_table :casebook_collaborators do |t|
      t.references :user, foreign_key: true
      t.references :casebook, foreign_key: true
      t.string :role

      t.timestamps
    end

    add_index :casebook_collaborators, [:user_id, :casebook_id], unique: true
  end
end
