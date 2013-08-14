class PlaylistItemRearch < ActiveRecord::Migration
  def self.up
    conxn = ActiveRecord::Base.connection
    conxn.execute("DELETE FROM playlist_items WHERE resource_item_type IN ('ItemAnnotation', 'ItemQuestion', 'ItemQuestionInstance')")

    add_column :playlist_items, :name, :string, :limit => 1024
    add_column :playlist_items, :url, :string, :limit => 1024 
    add_column :playlist_items, :description, :text
    add_column :playlist_items, :actual_object_type, :string, :limit => 255, :nil => false
    add_column :playlist_items, :actual_object_id, :integer, :nil => false

    # Boo: Rails 2.3 doesn't allow prepared statements
    # st = conxn.prepare("UPDATE playlist_items SET name = ?, url = ?, description = ?, actual_object_type = ?, actual_object_id = ? WHERE id = ?")
    playlist_items = conxn.execute("SELECT id, resource_item_type, resource_item_id FROM playlist_items WHERE resource_item_type IS NOT NULL ORDER BY id")
    playlist_items.each do |playlist_item|
      table = playlist_item["resource_item_type"].tableize
      puts "updating: #{playlist_item["id"]}"
      conxn.execute <<-SQL
        UPDATE playlist_items SET name                = (SELECT name FROM #{table} WHERE id = #{playlist_item["resource_item_id"]}),
                                  url                 = (SELECT url FROM #{table} WHERE id = #{playlist_item["resource_item_id"]}),
                                  description         = (SELECT description FROM #{table} WHERE id = #{playlist_item["resource_item_id"]}),
                                  actual_object_type  = (SELECT actual_object_type FROM #{table} WHERE id = #{playlist_item["resource_item_id"]}),
                                  actual_object_id    = (SELECT actual_object_id FROM #{table} WHERE id = #{playlist_item["resource_item_id"]})
        WHERE id = #{playlist_item["id"]}
      SQL
    end

    ["cases", "collages", "defaults", "medias", "playlists", "text_blocks",
     "youtubes", "images", "texts", "rotisserie_discussions", "annotations",
     "questions", "question_instances"].each do |type|
      conxn.execute("DROP TABLE item_#{type} CASCADE")
    end

    remove_column :playlist_items, :active
    remove_column :playlist_items, :ancestry
    remove_column :playlist_items, :playlist_item_parent_id
    remove_column :playlist_items, :public
    remove_column :playlist_items, :resource_item_id 
    remove_column :playlist_items, :resource_item_type
  end

  def self.down
    # No reverse for this cleanup
  end
end
