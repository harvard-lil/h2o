class AddDescriptionToMedias < ActiveRecord::Migration
  def self.up
    if connection.adapter_name.downcase == 'postgresql'
      add_column :medias, :description, :string, :limit => 5.megabytes 
    else
      add_column :medias, :description, :text, :limit => 5.megabytes
    end
  end

  def self.down
    remove_column :medias, :description
  end
end
