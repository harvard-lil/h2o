class AddingPreferencesToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :default_show_annotations, :boolean
    add_column :users, :tab_open_new_items, :boolean
    add_column :users, :default_font_size, :string
  end

  def self.down
    remove_column :users, :default_show_annotations
    remove_column :users, :tab_open_new_items
    remove_column :users, :default_font_size
  end
end
