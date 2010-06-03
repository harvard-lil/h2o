class AddVisibilityColumns < ActiveRecord::Migration
  def self.up
    add_column :playlists, :public, :boolean,  :default => true
    add_column :item_defaults, :public, :boolean,  :default => true
    add_column :item_images, :public, :boolean,  :default => true
    add_column :item_texts, :public, :boolean,  :default => true
    add_column :item_youtubes, :public, :boolean,  :default => true
    add_column :rotisserie_instances, :public, :boolean,  :default => true
    add_column :rotisserie_discussions, :public, :boolean,  :default => true
    add_column :rotisserie_posts, :public, :boolean,  :default => true
  end

  def self.down
    remove_column :playlists, :public
    remove_column :item_defaults, :public
    remove_column :item_images, :public
    remove_column :item_texts, :public
    remove_column :item_youtubes, :public
    remove_column :rotisserie_instances, :public
    remove_column :rotisserie_discussions, :public
    remove_column :rotisserie_posts, :public
  end
end
