class AddHighlightToAnnotations < ActiveRecord::Migration
  def change
    add_column :annotations, :highlight_only, :string
  end
end
