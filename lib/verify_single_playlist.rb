class VerifySinglePlaylist
  attr_accessor :casebook, :playlist, :casebook_sections, :free_resources, :bad_resources, :comments

  def self.verify(casebook)
    new(casebook).verify
  end

  def initialize(casebook)
    @casebook = casebook
    @playlist = Migrate::Playlist.find casebook.playlist_id
    @casebook_sections = Content::Section.where(casebook_id: casebook.id)
    @bad_resources = []
    @comments = true
  end

  def verify
    loop_playlist_items(playlist.playlist_items, path: [])
  end

  def loop_playlist_items(playlist_items, path:)
    # if comments == true
    #   puts "*************"
    #   puts "1 *~*"
    #   puts "starting loop_playlist_items"
    #   puts "playlist"
    #   puts "+ #{playlist.inspect}"
    #   puts "path"
    #   puts "+ #{path}"
    # end
    playlist_items.order(:position).each_with_index do |item, index|
      if item.actual_object_type.in? %w{Playlist Collage Media}
        item.actual_object_type = "Migrate::#{item.actual_object_type}"
      end

      object = item.actual_object
      ordinals = path + [index + 1]

      if object.is_a? Migrate::Playlist
        loop_playlist_items object.playlist_items, path: ordinals
      else
        imported_resource = object

        # if comment == true
        #   # if imported_resource.nil?
        #   #   bad_resources << [message: "nil imported_resource", type: item.actual_object_type, id: item.actual_object_id, url: "https://h2o.law.harvard.edu/#{item.actual_object_type.downcase}s/#{item.actual_object_id}"]
        #   # end
        # end

        casebook_resource = casebook.resources.find_by(ordinals: ordinals)

        puts "*****"
        puts ordinals
        puts casebook_resource.inspect
      end
      # if comment == true
        # if imported_resource.is_a? Migrate::Collage
        #   if imported_resource.annotatable_type == "Case"
        #     casebook.resources.find_by(ordinals: ordinals)
        #   elsif imported_resource.annotatable_type == "TextBlock"
        #   end

          # if imported_resource.annotatable_type.in? %w{Playlist Collage Media}
          #   imported_resource.annotatable_type = "Migrate::#{object.annotatable_type}"
          # end
          # imported_resource = imported_resource.annotatable

          # if imported_resource.nil?
          #   bad_resources << [message: "nil imported_resource", type: item.actual_object_type, id: item.actual_object_id, url: "https://h2o.law.harvard.edu/#{item.actual_object_type.downcase}s/#{item.actual_object_id}"]
          # end
        end
      # end

      # if imported_resource.is_a? Migrate::Media # this is a default
      # end

      # if casebook_content.is_a? Content::Section
      #   return
      # else
      #   resource = casebook_content.resource
      # end

      # if casebook_content != playlist_item
      #   # if comments == true
      #   #   puts "*************"
      #   #   puts "8 *~*"
      #   #   puts "BAD resource"
      #   # end
      #   bad_resources << [resource: resource, playlist: playlist_item]
      # end
  end
end



