class AddPolymorphismToAnnotations < ActiveRecord::Migration
  def change
    add_column :annotations, :annotated_item_id, :integer, :null => false, :default => 0
    add_column :annotations, :annotated_item_type, :string, :null => false, :default => 'Collage'

    connection.execute("UPDATE annotations SET annotated_item_type = 'Collage'")
    connection.execute("UPDATE annotations SET annotated_item_id = collage_id")
  end
end
