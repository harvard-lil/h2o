class ChangeVariableTypesInUnpublishedRevisions < ActiveRecord::Migration[5.1]
  def up
    change_column :unpublished_revisions, :casebook_id, :integer
    change_column :unpublished_revisions, :node_parent_id, :integer
  end

  def down
    change_column :unpublished_revisions, :casebook_id, :bigint
    change_column :unpublished_revisions, :node_parent_id, :bigint
  end
end
