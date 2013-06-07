class AddStatusToImports < ActiveRecord::Migration
  def self.up
    add_column :imports, :status, :string
  end

  def self.down
    remove_column :imports, :status
  end
end