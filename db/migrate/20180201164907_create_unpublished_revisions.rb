class CreateUnpublishedRevisions < ActiveRecord::Migration[5.1]
  def change
    create_table :unpublished_revisions do |t|
      t.integer :node_id
      t.string :field, null: false
      t.string :value, null: false

      t.timestamps
    end

    add_index :unpublished_revisions, [:node_id, :field]
  end
end
