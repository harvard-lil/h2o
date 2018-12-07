class AddHasAttributionToContentCollaborators < ActiveRecord::Migration[5.2]
  def up
    add_column :content_collaborators, :has_attribution, :boolean, default: false, null: false
  end

  def down
    remove_column, :content_collaborators, :has_attribution
  end
end
