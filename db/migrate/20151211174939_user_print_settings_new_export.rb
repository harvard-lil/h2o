class UserPrintSettingsNewExport < ActiveRecord::Migration
  def change
    add_column :users, :print_links, :boolean, :null => false, :default => true
    add_column :users, :toc_levels, :string, :null => false, :default => ''
    add_column :users, :print_export_format, :string, :null => false, :default => ''
  end
end
