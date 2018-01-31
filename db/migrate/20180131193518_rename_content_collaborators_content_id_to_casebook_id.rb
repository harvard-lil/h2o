class RenameContentCollaboratorsContentIdToCasebookId < ActiveRecord::Migration[5.1]
  def up
    rename_column :content_collaborators, :content_id, :casebook_id
  end

  def down
    rename_column :content_collaborators, :casebook_id, :content_id
  end
end
