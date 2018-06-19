module VerifySinglePlaylist
  class << self

  attr_accessor :casebook, :playlist, :casebook_sections, :free_resources

  def self.verify(casebook)
    new(casebook).verify
  end

  def new(casebook)
    @casebook = casebook
    @playlist = Migrate::Playlist.find casebook.playlist_id
    @casebook_sections = Content::Section.where(casebook_id: casebook.id)
    @free_resources = get_free_resources
  end

  def verify(casebook)
    # verify_items(playlist.playlist_items)
    loop_playlist_items(playlist, path: [])

  end


  def loop_playlist_items(playlist, path:)
    self.playlist_items.sort.each do |item, index|
      ordinals = path + [index + 1]
      if item.actual_object_type == "Playlist"
        item_playlist = Migrate::Playlist.find(item.actual_object_id)
        loop_playlist_items(item_playlist, path: ordinals)
      else
      end
    end
  end

  private



  def get_free_resources
    free_resources = []
    casebook.resources.each do |resource|
      if resource.ordinals.size == 1
        free_resources << resource
      end
    end
  end

  def check_playlist_items playlist
    playlist.playlist_items.each do |item|
      if item.actual_object_type == "Playlist"
        item_playlist = Migrate::Playlist.find(item.actual_object_id)
        check_playlist_items(item_playlist)
      else
      end
    end
  end
end

# Variables
casebook = Content::Casebook.find(17493)
resource = casebook.resources.find_by(ordinals: [1, 1, 1])
playlist = Migrate::Playlist.find(casebook.playlist_id)
section_1 = Migrate::Playlist.find(playlist.playlist_items.first.actual_object_id)
item = Migrate::Playlist.find(section_1.playlist_items.find_by(position: 1).actual_object_id).playlist_items.find_by(position: 1)
casebook_default = resource.resource
playlist_default = item.actual_object

end