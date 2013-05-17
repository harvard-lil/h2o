class AddPushedFromIdToAnnotationVersions < ActiveRecord::Migration
  def self.up
    add_column :collage_link_versions, :pushed_from_id, :integer
  end

  def self.down
    remove_column :collage_link_versions, :pushed_from_id
  end
end
