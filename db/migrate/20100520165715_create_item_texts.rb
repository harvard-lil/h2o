class CreateItemTexts < ActiveRecord::Migration
  def self.up
    create_table :item_texts do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :item_texts
  end
end
