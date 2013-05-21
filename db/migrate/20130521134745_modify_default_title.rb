class ModifyDefaultTitle < ActiveRecord::Migration
  def self.up
    change_column :defaults, :title, :string, :null => true, :limit => 1024
  end

  def self.down
    change_column :defaults, :title, :string, :null => false
  end
end
