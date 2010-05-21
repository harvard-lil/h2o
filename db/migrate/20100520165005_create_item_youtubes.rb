class CreateItemYoutubes < ActiveRecord::Migration
  def self.up
    create_table :item_youtubes do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :item_youtubes
  end
end
