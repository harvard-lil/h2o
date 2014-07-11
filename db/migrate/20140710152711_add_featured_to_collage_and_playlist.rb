class AddFeaturedToCollageAndPlaylist < ActiveRecord::Migration
  def change
    add_column :playlists, :featured, :boolean, :null => false, :default => false
    add_column :collages, :featured, :boolean, :null => false, :default => false

    connection.execute("UPDATE playlists SET featured = true WHERE id IN (1374, 1162, 671, 986, 5435, 945, 1510, 1324, 66)")
    connection.execute("UPDATE collages SET featured = true WHERE id IN (4245, 3459, 4239, 2758, 2773, 2774, 2431, 2753, 2426, 1322, 4238, 3876, 3654, 3786)")
  end
end
