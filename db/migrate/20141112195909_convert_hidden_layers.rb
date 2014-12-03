class ConvertHiddenLayers < ActiveRecord::Migration
  def up
    ["not required", "nonrequired", "optional", "hidden.", "hidden", "non-required", "omit", "nonreauired", "unrequired", "hide"].each do |tag|
      results = connection.select_rows("SELECT id, taggable_id FROM taggings WHERE tag_id = (SELECT id FROm tags WHERE name = '" + tag + "') AND taggable_type = 'Annotation'")
      results.each do |taggable_id, annotation_id|
        connection.execute("UPDATE annotations SET hidden = TRUE WHERE id = " + annotation_id)
        connection.execute("DELETE FROM taggings WHERE id = " + taggable_id)
      end
    end
  end
  def down
    #Nothing
  end
end
