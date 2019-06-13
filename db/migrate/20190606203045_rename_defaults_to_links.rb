class RenameDefaultsToLinks < ActiveRecord::Migration[5.2]
  def up
    rename_table :defaults, :links
  end

  def down
    rename_table :links, :defaults
  end
end
