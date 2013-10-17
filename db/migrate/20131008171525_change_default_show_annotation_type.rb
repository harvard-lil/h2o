class ChangeDefaultShowAnnotationType < ActiveRecord::Migration
  def self.up
    change_column :users, :default_show_annotations, :boolean, :null => false, :default => false
  end

  def self.down
    change_column :users, :default_show_annotations, :boolean
  end
end
