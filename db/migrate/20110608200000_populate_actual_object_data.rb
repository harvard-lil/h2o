class PopulateActualObjectData < ActiveRecord::Migration

  def self.up
    conxn = ActiveRecord::Base.connection
    ["annotations", "question_instances", "texts",
	  "cases", "images", "questions",
	  "collages", "playlists", "rotisserie_discussions"].each do |type|
	  conxn.execute("UPDATE item_#{type} SET actual_object_type = '#{type.classify}'")
	  conxn.execute("UPDATE item_#{type} SET actual_object_id = CAST(REGEXP_REPLACE(url, '.*\/', '') AS integer)")
	end
  end

  def self.down
    conxn = ActiveRecord::Base.connection
    ["annotations", "question_instances", "texts",
	  "cases", "images", "questions",
	  "collages", "playlists", "rotisserie_discussions"].each do |type|
	  conxn.execute("UPDATE item_#{type} SET actual_object_type = ''")
	  conxn.execute("UPDATE item_#{type} SET actual_object_id = ''")
	end
  end
end
