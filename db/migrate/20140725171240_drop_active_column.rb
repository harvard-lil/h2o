class DropActiveColumn < ActiveRecord::Migration
  def change
    connection.execute("UPDATE playlists SET public = FALSE WHERE active = FALSE");
    connection.execute("UPDATE collages SET public = FALSE WHERE active = FALSE");
    connection.execute("UPDATE text_blocks SET public = FALSE WHERE active = FALSE");
    connection.execute("UPDATE medias SET public = FALSE WHERE active = FALSE");
    connection.execute("UPDATE defaults SET public = FALSE WHERE active = FALSE");
    connection.execute("UPDATE cases SET public = FALSE WHERE active = FALSE");
    remove_column :playlists, :active
    remove_column :collages, :active
    remove_column :text_blocks, :active
    remove_column :medias, :active
    remove_column :defaults, :active
    remove_column :cases, :active
  end
end
