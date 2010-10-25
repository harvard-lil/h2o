class CreateTextBlocks < ActiveRecord::Migration
  def self.up
    create_table :text_blocks do |t|
      t.string :name, :limit => 255, :null => false

      if connection.adapter_name.downcase == 'postgresql'
        t.string :description, :limit => 5.megabytes, :null => false
      else
        t.text :description, :limit => 5.megabytes, :null => false
      end
      
      t.string :mime_type, :limit => 50, :default => 'text/plain'
      t.boolean :active, :default => true
      t.boolean :public, :default => true
      t.timestamps
    end
    
    [:name,:mime_type,:created_at,:updated_at].each do|col|
      add_index :text_blocks, col
    end

  end

  def self.down
    drop_table :text_blocks
  end
end
