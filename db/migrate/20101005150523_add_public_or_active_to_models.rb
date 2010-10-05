class AddPublicOrActiveToModels < ActiveRecord::Migration
  
  def self.up
    tables = [:cases, :collages, :annotations, :question_instances, :questions]
    tables.each do |table|
      add_column table, :public, :boolean, :default => true
      add_column table, :active, :boolean, :default => true
      add_index table, :public
      add_index table, :active
    end
    add_column :playlist_items, :public, :boolean, :default => true
    add_index :playlist_items, :public
  end

  def self.down
    tables = [:cases, :collages, :annotations, :question_instances, :questions]
    tables.each do|table|
      remove_column table, :public
      remove_column table, :active
    end
    remove_column :playlist_items, :public
  end
end
