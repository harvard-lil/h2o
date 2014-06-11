module SweeperHelper

  def clear_playlists(playlist_items)
    playlist_ids = playlist_items.collect { |pi| pi.playlist_id }.uniq
    playlists_to_clear = []
    playlists_to_clear = playlist_ids.inject([]) do |arr, pi|
      arr << pi
      arr << Playlist.find(pi).relation_ids
      arr.flatten
    end

    playlists_to_clear.uniq.each do |pid|
      ActionController::Base.expire_page "/playlists/#{pid}.html"
      ActionController::Base.expire_page "/playlists/#{pid}/export.html"
      Rails.cache.delete("playlist-wordcount-#{pid}")
    end
  end

  def notify_private(record)
    # if record.changed.include?("public") && record.public == false
    #  record.barcode.each do |barcode_tick|
    #    if barcode_tick[:title].match(/^Added to playlist/)
    #      playlist_id = barcode_tick[:link].gsub("/playlists/", '')
    #      playlist = Playlist.find(playlist_id)
    #      if playlist.user != record.user
    #        Notifier.item_made_private(playlist, record).deliver
    #      end
    #    end
    #  end
    # end
  end
end
