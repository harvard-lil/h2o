module SweeperHelper

  def clear_playlists(playlist_items)
    PlaylistItem.clear_playlists(playlist_items)
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
