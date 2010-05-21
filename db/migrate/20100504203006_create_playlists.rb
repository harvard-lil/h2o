class CreatePlaylists < ActiveRecord::Migration
  def self.up
    create_table :playlists do |t|
      t.string  :title, :null => false
      t.string  :output_text,   :limit => 1024
      t.text    :description
      t.boolean :active, :default => true
      t.timestamps
    end

    [:active].each do |col|
      add_index :playlists, col
    end
  end

  def self.down
    drop_table :playlists
  end
end
