class CreatePermissions < ActiveRecord::Migration
  def self.up
    create_table :permissions do |t|
      t.string :key
      t.string :label
      t.timestamps
    end

    [:position_update, :edit_collage, :edit_descriptions, :edit_annotations, :edit_notes].each do |p|
      Permission.create(:key => p.to_s, :label => p.to_s.titleize)
    end
  end

  def self.down
    drop_table :permissions
  end
end
