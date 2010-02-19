class CreateRotisserieInstances < ActiveRecord::Migration
  def self.up
    create_table :rotisserie_instances do |t|
      t.string    :title, :limit => 250, :null => false
      t.text      :output
      t.text      :description
      t.text      :notes
      t.string    :session_id
      t.boolean   :active, :default => true
      t.timestamps
    end

    add_index :rotisserie_instances, :title, :unique => true
  end

  def self.down
    drop_table :rotisserie_instances
  end
end
