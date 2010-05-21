class CreateItemImages < ActiveRecord::Migration
  def self.up
    create_table :item_images do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :item_images
  end
end
