class AddContentTypeToDefaults < ActiveRecord::Migration
  def self.up
    add_column :defaults, :content_type, :string
  end

  def self.down
    remove_column :defaults, :content_type
  end
end
