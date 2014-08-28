class DropMimeTypeFromTexts < ActiveRecord::Migration
  def change
    remove_column :text_blocks, :mime_type
  end
end
