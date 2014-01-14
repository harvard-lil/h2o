class ExtendDefaultUrlLength < ActiveRecord::Migration
  def self.up
    change_column :defaults, :url, :string, :limit => 1024
  end

  def self.down
    change_column :defaults, :url, :string, :limit => 255
  end
end
