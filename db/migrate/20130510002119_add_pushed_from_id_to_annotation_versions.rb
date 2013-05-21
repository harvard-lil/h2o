class AddPushedFromIdToAnnotationVersions < ActiveRecord::Migration
  def self.up
    #TIMCASE: This migration is commented out because we
    #pulled versioning and it's dependent on versioning migrations
    #add_column :collage_link_versions, :pushed_from_id, :integer
  end

  def self.down
    #remove_column :collage_link_versions, :pushed_from_id
  end
end
