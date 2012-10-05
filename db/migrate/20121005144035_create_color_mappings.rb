class CreateColorMappings < ActiveRecord::Migration
  def self.up
    create_table :color_mappings do |t|
      t.references :collage
      t.references :tag
      t.string :hex
      t.timestamps
    end
  end

  def self.down
    drop_table :color_mappings
  end
end
