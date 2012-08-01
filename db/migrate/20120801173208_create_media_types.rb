class CreateMediaTypes < ActiveRecord::Migration
  def self.up
    create_table :media_types do |t|
      t.string :label
      t.string :slug
      t.timestamps
    end
    MediaType.create(:label => "Image", :slug => "image")
    MediaType.create(:label => "Video", :slug => "video")
    MediaType.create(:label => "Audio", :slug => "audio")
    MediaType.create(:label => "PDF", :slug => "pdf")
  end

  def self.down
    drop_table :media_types
  end
end
