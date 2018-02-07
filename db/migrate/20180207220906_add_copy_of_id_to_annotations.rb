class AddCopyOfIdToAnnotations < ActiveRecord::Migration[5.1]
  def up
    add_column :content_annotations, :copy_of_id, :bigint, index: true
  end

  def down
    remove_column :content_annotations, :copy_of_id
  end
end
