class VerifySinglePlaylist
  attr_accessor :casebook, :playlist, :mismatched, :items_without_resources

  def self.verify(casebook_id)
    new(casebook_id).verify
  end

  def initialize(casebook_id)
    @casebook = Content::Casebook.find(casebook_id)
    @playlist = Migrate::Playlist.find casebook.playlist_id
    @mismatched = {}
    @items_without_resources = {}
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
          items_without_resources[ordinals] = object
        elsif section.title != object.name
          mismatched[ordinals.join('.')] = {section: section, object: object}
        end

        loop_playlist_items object.playlist_items, path: ordinals
      else
        resource = casebook.resources.find_by(ordinals: ordinals)

        if resource.nil? || item.nil? || object.nil? || item.actual_object_type == "Migrate::Media"
          # videos weren't transported over so any Migrate::Media is counted as missing
          items_without_resources[ordinals] = item
        elsif item.actual_object_type == "Migrate::Collage"
          if object.annotatable.nil? 
            items_without_resources[ordinals] = item
          elsif object.annotatable.id != resource.resource.id
            mismatched[ordinals.join('.')] = {resource: resource, item: item}
          end
        elsif object.id != resource.resource.id
          mismatched[ordinals.join('.')] = {resource: resource, item: item}
        end
      end
    end
  end
end



