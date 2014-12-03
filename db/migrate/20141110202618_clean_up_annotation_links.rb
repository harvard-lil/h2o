class CleanUpAnnotationLinks < ActiveRecord::Migration
  def change
    rename_column :annotations, :linked_collage_id, :link
    change_column :annotations, :link, :string
    connection.execute("UPDATE annotations SET link = 'https://h2o.law.harvard.edu/collages/' || link WHERE link IS NOT NULL");
  end
end
