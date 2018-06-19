class VerifySinglePlaylist
  attr_accessor :casebook, :playlist, :casebook_sections, :free_resources, :bad_resources

  def self.verify(casebook)
    new(casebook).verify
  end

  def initialize(casebook)
    @casebook = casebook
    @playlist = Migrate::Playlist.find casebook.playlist_id
    @casebook_sections = Content::Section.where(casebook_id: casebook.id)
    @bad_resources = []
  end

  def verify
    loop_playlist_items(playlist, path: [])
  end

  def loop_playlist_items(playlist, path:)
    puts "*************"
    puts "1 *~*"
    puts "starting loop_playlist_items"
    puts "playlist"
    puts "+ #{playlist.inspect}"
    puts "path"
    puts "+ #{path}"
    playlist.playlist_items.sort.each_with_index do |item, index|
      puts "*************"
      puts "2 *~*"
      puts "item"
      puts "+ #{item.inspect}"
      ordinals = path + [index + 1]
      puts "ordinals"
      puts "+ #{ordinals}"
      if item.actual_object_type == "Playlist"
        puts "*************"
        puts "3 *~*"
        puts "TYPE"
        puts "Playlist"
        item_playlist = Migrate::Playlist.find(item.actual_object_id)
        loop_playlist_items(item_playlist, path: ordinals)
      else
        puts "*************"
        puts "4 *~*"
        puts "TYPE"
        puts item.actual_object_type
        casebook_content = casebook.contents.find_by(ordinals: ordinals)

        puts "*************"
        puts "5 *~*"
        puts "casebook content"
        puts "+ #{casebook_content.inspect}"
        # ordinals contain sections but sections don't have resources so not sure what I'm trying to do here. I don't think return is working? 
        # need to think about looping through playlist playlit items that are sections and also using the items that aren't in a section 

        if casebook_content.is_a? Content::Section
          puts "*************"
          puts "6 *~*"
          puts "In section suposed to be returning"
          return
        else
          resource = casebook_content.resource
        end

        puts "*************"
        puts "7 *~*"
        puts "outside of if/else"

        playlist_item = item.actual_object
        puts "*************"
        puts "8 *~*"
        puts "playlist item"
        puts " + #{playlist_item.inspect}"

        puts "resource "
        puts "+ #{resource.inspect}"

        if casebook_content != playlist_item
          puts "*************"
          puts "9 *~*"
          puts "BAD resource"
          bad_resources << [resource: resource, playlist: playlist_item]
        end
      end
    end
  end

  private

end



