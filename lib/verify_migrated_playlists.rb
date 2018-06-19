# casebook = Content::Casebook.find(17493)

# casebook, loop through sections 
# pull all 

module VerifyMigratedPlaylists
  class << self

    def verify
      casebooks.each do |casebook|
        VerifySinglePlaylist.verify casebook
      end
    end
end

module VerifySinglePlaylist
  class << self

  

  def self.verify(casebook)
    new(casebook).verify
  end

  def new(casebook)
    @casebook = casebook
    @playlist = Migrate::Playlist.find casebook.playlist_id
    @sections = Content::Section.where(casebook_id: casebook.id)
  end

  def verify(casebook)
    
    check_playlist_items playlist
    free_resources = get_free_resources playlist
  end

  private

  attr_accessor :casebook, :playlist, :sections
end



# /////

def get_free_resources casebook
  free_resources = []

  casebook.resources.each do |resource|
    if resource.ordinals.size == 1
      free_resources << resource
    end
  end
end


misc 

def check_playlist_items playlist
  playlist.playlist_items.each do |item|
    if item.actual_object_type == "Playlist"
      item_playlist = Migrate::Playlist.find(item.actual_object_id)
      check_playlist_items(item_playlist)
    else

    end
  end
end