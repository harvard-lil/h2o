class CreateUserCollections < ActiveRecord::Migration
  def self.up
    create_table :user_collections do |t|
      t.references :owner
      t.string :name
      t.string :description
      t.timestamps
    end
    
    create_table :user_collections_users, :id => false, :force => true do |t|
      t.references :user
      t.references :user_collection
    end
  end

  def self.down
    drop_table :user_collections
    drop_table :user_collections_users
  end
end
