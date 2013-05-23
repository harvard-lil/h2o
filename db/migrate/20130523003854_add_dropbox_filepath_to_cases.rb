class AddDropboxFilepathToCases < ActiveRecord::Migration
  def self.up
    add_column :cases, :dropbox_filepath, :string
  end

  def self.down
    remove_column :cases, :dropbox_filepath
  end
end