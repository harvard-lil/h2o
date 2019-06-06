class RenameDefaultToLink < ActiveRecord::Migration[5.2]
  def up
    rename_table :default, :link
  end

  def down
    rename_table :link, :default
  end
end
