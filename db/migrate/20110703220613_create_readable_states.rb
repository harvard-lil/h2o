class CreateReadableStates < ActiveRecord::Migration
  def self.up
    create_table :readable_states do |t|
      t.text :state
      t.timestamps
    end
  end

  def self.down
    drop_table :readable_states
  end
end
