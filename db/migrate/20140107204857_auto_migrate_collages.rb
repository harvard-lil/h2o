class AutoMigrateCollages < ActiveRecord::Migration
  def self.up
    # Do all this later
    #execute "UPDATE collages SET annotator_version = 2 WHERE id NOT IN (SELECT collage_id FROM annotations) AND id NOT IN (SELECT host_collage_id FROM collage_links)"

    #Collage.find_in_batches(:batch_size => 100, :conditions => { :annotator_version => 1 }) do |collage_batch|
    #  collage_batch.each do |collage|
    #    collage.upgrade_via_nokogiri
    #  end
    #end

    #execute "UPDATE collages SET readable_state = NULL"
    #execute "UPDATE collages SET words_shown = word_count"
    # TODO: Change default of annotator version to 2

    # Later, later TODO: DELETE ALL COLLAGE LINKS, Remove CollageLink model, Remove tt columns from collages
  end

  def self.down
  end
end
