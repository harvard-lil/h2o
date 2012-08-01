class CreateMedias < ActiveRecord::Migration
  def self.up
    create_table :medias do |t|
      t.string :name
      t.text :content
      t.references :media_type
      t.boolean :public, :default => true
      t.boolean :active, :default => true
      t.timestamps
    end
  end

  def self.down
    drop_table :medias
  end
end
