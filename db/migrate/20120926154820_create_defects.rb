class CreateDefects < ActiveRecord::Migration
  def self.up
    create_table :defects do |t|
      t.text :description, :null => false
	  t.integer :reportable_id, :null => false
	  t.string :reportable_type, :null => false
	  t.integer :user_id, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :defects
  end
end
