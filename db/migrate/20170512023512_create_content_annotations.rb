class CreateContentAnnotations < ActiveRecord::Migration[5.1]
  def change
    create_table :content_annotations do |t|
      t.references :resource, null: false, index: true, foreign_key: {to_table: :content_nodes}

      t.integer :start_p, null: false
      t.integer :end_p, null: true
      t.integer :start_offset, null: false
      t.integer :end_offset, null: false

      t.string :kind, null: false
      t.text :content, null: true

      t.timestamps
    end

    add_index :content_annotations, [:resource_id, :start_p]
  end
end
