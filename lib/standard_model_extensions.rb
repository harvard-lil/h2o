module StandardModelExtensions
  module InstanceMethods

    def barcode_breakdown
      self.barcode.inject({}) { |h, b| h[b[:type].to_sym] ||= 0; h[b[:type].to_sym] += 1; h }
    end

    def barcode_bookmarked_added
      elements = []
      item_klass = "Item#{self.class}".constantize
      item_klass.find_all_by_actual_object_id(self.id).each do |item|
        next if item.playlist_item.nil?
        next if item.playlist_item.playlist.nil?
        playlist = item.playlist_item.playlist
        if playlist.name == "Your Bookmarks"
          playlist_owner = playlist.accepted_roles.find_by_name('owner')
          elements << { :type => "bookmark",
                                :date => item.created_at,
                                :title => "Bookmarked by #{playlist_owner.user.display}",
                                :link => user_path(playlist_owner.user) }
        else
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
