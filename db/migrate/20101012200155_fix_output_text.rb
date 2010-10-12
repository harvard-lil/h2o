class FixOutputText < ActiveRecord::Migration
  def self.up
    [:item_annotations,:item_cases,:item_collages,:item_defaults,:item_images,:item_playlists,:item_question_instances ,:item_questions,:item_rotisserie_discussions,:item_texts,:item_youtubes,:playlists].each do|table|
      rename_column table, :output_text, :name
    end
  end

  def self.down
    [:item_annotations,:item_cases,:item_collages,:item_defaults,:item_images,:item_playlists,:item_question_instances ,:item_questions,:item_rotisserie_discussions,:item_texts,:item_youtubes,:playlists].each do|table|
      rename_column table, :name, :output_text
    end
  end
end
