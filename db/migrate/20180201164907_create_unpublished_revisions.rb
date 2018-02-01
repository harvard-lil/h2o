class CreateUnpublishedRevisions < ActiveRecord::Migration[5.1]
  def change
    create_table :unpublished_revisions do |t|
      t.references :resource, null: false, index: true, foreign_key: {to_table: :content_nodes}

      t.string :field, null: false
      t.string :original_value, null: false
      t.string :new_value, null: false

      t.timestamps
    end

    add_index :unpublished_revisions, [:resource_id, :field]
  end
end
