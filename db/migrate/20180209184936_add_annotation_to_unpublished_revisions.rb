class AddAnnotationToUnpublishedRevisions < ActiveRecord::Migration[5.1]
  def up
    add_column :unpublished_revisions, :annotation_id, :integer
  end

  def down
    remove_column :unpublished_revisions, :annotation_id
  end
end
