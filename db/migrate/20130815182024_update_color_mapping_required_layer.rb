class UpdateColorMappingRequiredLayer < ActiveRecord::Migration
  def self.up
    conxn = ActiveRecord::Base.connection
    conxn.execute("UPDATE color_mappings SET hex = '6b00000' WHERE tag_id = 46")
  end

  def self.down
    # no reverse
  end
end
