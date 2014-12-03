class AddHideToAnnotation < ActiveRecord::Migration
  def change
    add_column :annotations, :hidden, :boolean, :null => false, :default => false
    remove_column :annotations, :annotation_start
    remove_column :annotations, :annotation_end
    remove_column :annotations, :annotated_content
  end
end
