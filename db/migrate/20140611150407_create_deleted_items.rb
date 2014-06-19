class CreateDeletedItems < ActiveRecord::Migration
  def change
    create_table :deleted_items do |t|
      t.integer :item_id 
      t.string :item_type
      t.datetime :deleted_at
    end
  end
end
