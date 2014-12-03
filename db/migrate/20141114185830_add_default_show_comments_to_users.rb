class AddDefaultShowCommentsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :default_show_comments, :boolean, :null => false, :default => false
    remove_column :users, :default_show_annotations
  end
end
