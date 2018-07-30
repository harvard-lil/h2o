class RemovePushedFromIdFromModels < ActiveRecord::Migration[5.1]
  def change
    remove_column :annotations, :pushed_from_id, :integer
    remove_column :cases, :pushed_from_id, :integer
    remove_column :collages, :pushed_from_id, :integer
    remove_column :defaults, :pushed_from_id, :integer
    remove_column :medias, :pushed_from_id, :integer
    remove_column :playlist_items, :pushed_from_id, :integer
    remove_column :playlists, :pushed_from_id, :integer
    remove_column :text_blocks, :pushed_from_id, :integer
  end
end
