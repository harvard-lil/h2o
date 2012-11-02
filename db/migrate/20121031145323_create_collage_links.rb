class CreateCollageLinks < ActiveRecord::Migration
  def self.up
    create_table :collage_links do |t|
      t.integer :host_collage_id, :null => false
      t.integer :linked_collage_id, :null => false
      t.string  :link_text_start, :null => false
      t.string  :link_text_end, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :collage_links
  end
end
