class Playlist < ActiveRecord::Base
  has_many :playlist_items, :order => :position
  has_many :items, :through => :playlist_items, :order => "playlist_items.position"

end
