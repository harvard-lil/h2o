class AddPushedFromIdToDefaults < ActiveRecord::Migration
  def self.up
    add_column :defaults, :pushed_from_id, :integer
    add_column :collage_links, :pushed_from_id, :integer
  end

  def self.down
    remove_column :defaults, :pushed_from_id
    remove_column :collage_links, :pushed_from_id
  end
end
