class AddRemixedFromIdToAnnotations < ActiveRecord::Migration
  def self.up
    add_column :annotations, :cloned, :boolean, :null => false, :default => false

    Collage.find(:all, :conditions => "ancestry IS NOT NULL").each do |collage|
      root_collage = collage.root
      collage.annotations.each do |annotation|
        matching_annotation = root_collage.annotations.detect { |a| a.created_at == annotation.created_at && a.annotation_start == annotation.annotation_start && a.annotation_end = annotation.annotation_end }
        if matching_annotation.present?
          annotation.update_attribute(:cloned, true)
          puts "Updated annotation #{annotation.id}"
        end
      end
    end
  end

  def self.down
    remove_column :annotations, :cloned
  end
end
