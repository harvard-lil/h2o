class RemoveCollageLinks < ActiveRecord::Migration
  def change
    connection.execute("DROP TABLE collage_links CASCADE")
  end
end
