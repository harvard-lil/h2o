class AddUserDetailFields < ActiveRecord::Migration
  def self.up
    add_column :users, :title, :string
    add_column :users, :affiliation, :string
    add_column :users, :url, :string
    add_column :users, :description, :text
  end

  def self.down
    remove_column :users, :title
    remove_column :users, :affiliation
    remove_column :users, :url
    remove_column :users, :description
  end
end
