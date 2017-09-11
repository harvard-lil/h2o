class MakeContentDeletesCascade < ActiveRecord::Migration[5.1]
  def change
    remove_foreign_key :content_annotations, column: :resource_id
    add_foreign_key :content_annotations, :content_nodes, column: :resource_id, on_delete: :cascade

    remove_foreign_key :content_nodes, column: :casebook_id
    add_foreign_key :content_nodes, :content_nodes, column: :casebook_id, on_delete: :cascade

    remove_foreign_key :content_nodes, column: :copy_of_id
    add_foreign_key :content_nodes, :content_nodes, column: :copy_of_id, on_delete: :nullify
  end
end
