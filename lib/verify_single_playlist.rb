class VerifySinglePlaylist
  attr_accessor :casebook, :playlist, :mismatched, :object, :item, :resource, :section, :ordinals

  def self.verify(casebook_id)
    new(casebook_id).verify
  end

  def initialize(casebook_id)
    @casebook = Content::Casebook.find(casebook_id)
    @playlist = Migrate::Playlist.find(casebook.playlist_id)
    @mismatched = {}
  end

  def verify
    loop_playlist_items(playlist.playlist_items, path: [])
    mismatched
  end

  def set_variables(item, path, index)
    @item = item
    set_class_names_for_playlist_items
    @object = item.actual_object
    @ordinals = path + [index + 1]
  end

  def set_class_names_for_playlist_items
    if item.actual_object_type.in? %w{Playlist Collage Media}
      item.actual_object_type = "Migrate::#{item.actual_object_type}"
    end
  end

  def loop_again?
    object.is_a? Migrate::Playlist
  end

  def bad_item_or_resource?
    resource.nil? || item.nil? || object.nil? || item.actual_object_type == "Migrate::Media" || object.try(:annotatable)
    # videos weren't transported over so any Migrate::Media is counted as missing
  end

  def mismatched_section?
    ! section.nil? && section.title != object.name 
  end

  def mismatched_resource?
    object.annotatable.id != resource.resource.id 
  end

  def mismatched_link?
    object.id != resource.resource.id
  end

  def loop_playlist_items(playlist_items, path:)
    playlist_items.order(:position).each_with_index do |item, index|
      set_variables(item, path, index)
      
      if loop_again?
        @section = casebook.contents.find_by(ordinals: ordinals)

        if mismatched_section?
          mismatched[ordinals.join('.')] = {section: section, object: object}
        end

        loop_playlist_items(object.playlist_items, path: ordinals)
      else
        @resource = casebook.resources.find_by(ordinals: ordinals)

        if bad_item_or_resource?
          return
        elsif item.actual_object_type == "Migrate::Collage"
          if mismatched_resource?
            mismatched[ordinals.join('.')] = {resource: resource, item: item}
          end
        elsif mismatched_link?
          mismatched[ordinals.join('.')] = {resource: resource, item: item}
        end
      end
    end
  end
end



