class CreateLocationsAndPeripheral < ActiveRecord::Migration
  def self.up
    create_table :locations do |t|
      t.string :name, :null => false
      t.timestamps
    end

    add_column :playlists, :location_id, :integer
    add_column :playlists, :when_taught, :string

    Location.create({ :name => "University #1" })
    Location.create({ :name => "University #2" })
  end

  def self.down
    drop_table :locations

    remove_column :playlists, :location_id
    remove_column :playlists, :when_taught
  end
end
