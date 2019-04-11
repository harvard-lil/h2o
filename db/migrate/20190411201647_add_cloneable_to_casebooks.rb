class AddCloneableToCasebooks < ActiveRecord::Migration[5.2]
  def up
    add_column :content_nodes, :cloneable, :boolean, default: true, null: false
  end

  def down
    remove_column :content_nodes, :cloneable
  end
end
