class AddReadableStateToCollages < ActiveRecord::Migration
  def self.up
	  #Note: The following limit arg did not work on murk, so ALTER TABLE added 
    add_column :collages, :readable_state, :text #, :limit => 5.kilobytes
	  execute "ALTER TABLE collages ALTER COLUMN readable_state TYPE varchar(5242880)"
  end

  def self.down
    remove_column :collages, :readable_state
  end
end
