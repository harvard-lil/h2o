class CreateResponses < ActiveRecord::Migration
  def change
    create_table :responses do |t|
      t.text :content
      t.integer :user_id, :null => false
      t.string :resource_type, :null => false
      t.integer :resource_id, :null => false
      t.datetime :created_at
    end
  end
end
