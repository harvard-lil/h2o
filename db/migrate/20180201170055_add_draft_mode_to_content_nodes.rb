class AddDraftModeToContentNodes < ActiveRecord::Migration[5.1]
  def up
    add_column :content_nodes, :draft_mode, :boolean, index: true
  end

  def down
    remove_column :content_nodes, :draft_mode, :boolean, index: true
  end
end
