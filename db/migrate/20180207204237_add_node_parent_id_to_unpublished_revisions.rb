class AddNodeParentIdToUnpublishedRevisions < ActiveRecord::Migration[5.1]
  def up
    add_column :unpublished_revisions, :node_parent_id, :bigint, index: true
  end

  def down
    remove_column :unpublished_revisions, :node_parent_id
  end
end
