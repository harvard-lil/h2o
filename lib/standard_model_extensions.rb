module StandardModelExtensions
  module InstanceMethods
    def stored(field)
      self.send(field)
    end

    def barcode_breakdown
      self.barcode.inject({}) { |h, b| h[b[:type].to_sym] ||= 0; h[b[:type].to_sym] += 1; h }
    end

    def playlists_included_ids
      PlaylistItem.find(:all, :conditions => { :actual_object_type => self.class.to_s, :actual_object_id => self.id }, :select => :playlist_id)
    end

    def barcode_bookmarked_added
      elements = []
      PlaylistItem.find_all_by_actual_object_id_and_actual_object_type(self.id, self.class.to_s).each do |item|
        next if item.playlist.nil?
        playlist = item.playlist
        if playlist.name == "Your Bookmarks"
          elements << { :type => "bookmark",
                                :date => item.created_at,
                                :title => "Bookmarked by #{playlist.user.display}",
                                :link => user_path(playlist.user) }
        elsif playlist.public
          elements << { :type => "add",
                                :date => item.created_at,
                                :title => "Added to playlist #{playlist.name}",
                                :link => playlist_path(playlist.id) }
        end
      end
      elements
    end
  end
end
