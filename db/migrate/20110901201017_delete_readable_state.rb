class DeleteReadableState < ActiveRecord::Migration
  def self.up
    drop_table :readable_states
  end

  def self.down
    create_table :readable_states do |t|
      t.text :state
      t.timestamps
    end
  end
end
