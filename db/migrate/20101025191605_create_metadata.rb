class CreateMetadata < ActiveRecord::Migration
  def self.up
    create_table :metadata do |t|
      t.string :contributor, :limit => 255
      t.string :coverage, :limit => 255
      t.string :creator, :limit => 255
      t.date :date
      if connection.adapter_name.downcase == 'postgresql'
        t.string :description, :limit => 5.megabytes
      else
        t.text :description, :limit => 5.megabytes
      end
      t.string :format, :limit => 255
      t.string :identifier, :limit => 255
      t.string :language, :limit => 255
      t.string :publisher, :limit => 255
      t.string :relation, :limit => 255
      t.string :rights, :limit => 255
      t.string :source, :limit => 255
      t.string :subject, :limit => 255
      t.string :title, :limit => 255
      t.string :dc_type, :limit => 255, :default => 'text'
      t.string :classifiable_type, :limit => 255
      t.integer :classifiable_id

      t.timestamps
    end
    [:classifiable_type, :classifiable_id].each do|col|
      add_index :metadata, col
    end
  end

  def self.down
    drop_table :metadata
  end
end
