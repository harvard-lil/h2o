class AddLinkedCollageToAnnotation < ActiveRecord::Migration
  def self.up
    add_column :annotations, :linked_collage_id, :integer
  end

  def self.down
    remove_column :annotations, :linked_collage_id
  end
end
