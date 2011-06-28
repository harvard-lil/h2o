class AddReadableStateToCollages < ActiveRecord::Migration
  def self.up
    add_column :collages, :readable_state, :text, :limit => 5.kilobytes
  end

  def self.down
    remove_column :collages, :readable_state
  end
end
