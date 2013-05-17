class AddCopiedFromIdToItemObjects < ActiveRecord::Migration
  def self.up
    add_column :item_annotations, :pushed_from_id, :integer
    add_column :item_cases, :pushed_from_id, :integer
    add_column :item_collages, :pushed_from_id, :integer
    add_column :item_defaults, :pushed_from_id, :integer
    add_column :item_medias, :pushed_from_id, :integer
    add_column :item_playlists, :pushed_from_id, :integer
    add_column :item_questions, :pushed_from_id, :integer
    add_column :item_question_instances, :pushed_from_id, :integer
    add_column :item_rotisserie_discussions, :pushed_from_id, :integer
    add_column :item_text_blocks, :pushed_from_id, :integer
  end

  def self.down
    remove_column :item_annotations, :pushed_from_id
    remove_column :item_cases, :pushed_from_id
    remove_column :item_collages, :pushed_from_id
    remove_column :item_defaults, :pushed_from_id
    remove_column :item_medias, :pushed_from_id
    remove_column :item_playlists, :pushed_from_id
    remove_column :item_questions, :pushed_from_id
    remove_column :item_question_instances, :pushed_from_id
    remove_column :item_rotisserie_discussions, :pushed_from_id
    remove_column :item_text_blocks, :pushed_from_id
  end
end