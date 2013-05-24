class ChangeActualObjectTypeToStringOnImports < ActiveRecord::Migration
  def self.up
    change_column :imports, :actual_object_type, :string
  end

  def self.down
    change_column :imports, :actual_object_type, :string
  end
end