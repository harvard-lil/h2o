class RenameCasebooksToContents < ActiveRecord::Migration[5.1]
  def change
    rename_table :casebooks, :content_nodes
    rename_column :content_nodes, :book_id, :casebook_id

    rename_table :casebook_collaborators, :content_collaborators
    rename_column :content_collaborators, :casebook_id, :content_id
  end
end
