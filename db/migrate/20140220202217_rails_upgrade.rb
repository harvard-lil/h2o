class RailsUpgrade < ActiveRecord::Migration
  def change
    connection.execute("DELETE FROM roles WHERE name = 'editor' AND authorizable_type IN ('Annotation', 'Collage', 'Playlist')")
    connection.execute("ALTER TABLE playlists DROP COLUMN title")
    connection.execute("DROP TABLE notification_trackers CASCADE")
    connection.execute("DROP TABLE notification_invites CASCADE")
  end
end
