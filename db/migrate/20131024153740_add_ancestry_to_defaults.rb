class AddAncestryToDefaults < ActiveRecord::Migration
  def self.up
    add_column :defaults, :ancestry, :string
  end

  def self.down
    remove_column :defaults, :ancestry
  end
end
