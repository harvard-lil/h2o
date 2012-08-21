class CreateCollagesUserCollections < ActiveRecord::Migration
  def self.up
    create_table :collages_user_collections, :id => false, :force => true do |t|
      t.references :collage
      t.references :user_collection
    end

    add_column :permissions, :permission_type, :string
    [:position_update, :edit_descriptions, :edit_notes].each do |key|
      Permission.find_by_key(key.to_s).update_attribute(:permission_type, "playlist")
    end
    [:edit_collage, :edit_annotations].each do |key|
      Permission.find_by_key(key.to_s).update_attribute(:permission_type, "collage")
    end
  end

  def self.down
    drop_table :collages_user_collections

    remove_column :permissions, :permission_type
  end
end
