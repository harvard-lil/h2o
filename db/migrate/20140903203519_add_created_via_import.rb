class AddCreatedViaImport < ActiveRecord::Migration
  def change
    add_column :medias, :created_via_import, :boolean, :null => false, :default => false
    add_column :playlists, :created_via_import, :boolean, :null => false, :default => false
    add_column :defaults, :created_via_import, :boolean, :null => false, :default => false
    add_column :text_blocks, :created_via_import, :boolean, :null => false, :default => false
    add_column :collages, :created_via_import, :boolean, :null => false, :default => false
    add_column :cases, :created_via_import, :boolean, :null => false, :default => false
  end
end
