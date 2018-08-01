class RenameAnnotationColumns < ActiveRecord::Migration[5.1]
  def change
    rename_column :content_annotations, :start_p, :start_paragraph
    rename_column :content_annotations, :end_p, :end_paragraph
  end
end
