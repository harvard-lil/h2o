class VerifySinglePlaylist
  attr_accessor :casebook, :playlist, :matches, :comments, :mismatches, :mismatched, :items_without_resources

  def self.verify(casebook_id)
    new(casebook_id).verify
  end

  def initialize(casebook_id)
    @casebook = Content::Casebook.find(casebook_id)
    @playlist = Migrate::Playlist.find casebook.playlist_id
    @matches = []
    @mismatches = []
    @mismatched = false
    @comments = true
    @items_without_resources = []
  end

  def verify
    loop_playlist_items(playlist.playlist_items, path: [])
    {mismatched: mismatched, items_without_resources: items_without_resources}
  end

  def loop_playlist_items(playlist_items, path:)
    playlist_items.order(:position).each_with_index do |item, index|
      if item.actual_object_type.in? %w{Playlist Collage Media}
        item.actual_object_type = "Migrate::#{item.actual_object_type}"
      end

      object = item.actual_object
      ordinals = path + [index + 1]

      if object.is_a? Migrate::Playlist
        section = casebook.contents.find_by(ordinals: ordinals)

        if section.nil?
          items_without_resources << object
        elsif section.title != object.name
          mismatched = true
        end

        loop_playlist_items object.playlist_items, path: ordinals
      else
        resource = casebook.resources.find_by(ordinals: ordinals)
        if resource.nil?
          items_without_resources << item
        elsif object != resource.resource
          mismatched = true
        end
      end
    end
  end
end



