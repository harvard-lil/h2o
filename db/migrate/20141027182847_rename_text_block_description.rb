class RenameTextBlockDescription < ActiveRecord::Migration
  def change
    rename_column :text_blocks, :description, :content
    add_column :text_blocks, :description, :string, :limit => 5.megabytes
  end
end
