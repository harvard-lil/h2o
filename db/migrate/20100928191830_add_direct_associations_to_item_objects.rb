class AddDirectAssociationsToItemObjects < ActiveRecord::Migration

  def self.up
    [:item_annotations, :item_question_instances, :item_texts,
      :item_cases, :item_images, :item_questions,
      :item_collages, :item_playlists, :item_rotisserie_discussions].each do|table|
      add_column table, :actual_object_type, :string
      add_column table, :actual_object_id, :integer
      add_index table, :actual_object_id
      add_index table, :actual_object_type
    end
  end

  def self.down
    [:item_annotations, :item_question_instances, :item_texts,
      :item_cases, :item_images, :item_questions,
      :item_collages, :item_playlists, :item_rotisserie_discussions].each do|table|
      remove_column table, :actual_object_type
      remove_column table, :actual_object_id
    end
  end
end
