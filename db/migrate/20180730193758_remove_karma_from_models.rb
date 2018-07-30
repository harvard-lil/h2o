class RemoveKarmaFromModels < ActiveRecord::Migration[5.1]
  def change
    remove_column :cases, :karma, :integer
    remove_column :collages, :karma, :integer
    remove_column :defaults, :karma, :integer
    remove_column :medias, :karma, :integer
    remove_column :playlists, :karma, :integer
    remove_column :text_blocks, :karma, :integer
    remove_column :users, :karma, :integer
  end
end
