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
      expire_page :controller => :playlists, :action => :show, :id => pid
      expire_page :controller => :playlists, :action => :export, :id => pid
      Rails.cache.delete("playlist-wordcount-#{pid}")
    end
  end

  def expire_question_instance(record)
    #no sort order specified, so the sort order is "null"
    expire_fragment("question-instance-index-#{record.id}-false-null")
    expire_fragment("question-instance-index-#{record.id}-true-null")
    expire_fragment("question-instance-index-#{record.id}-false-")
    expire_fragment("question-instance-index-#{record.id}-true-")
    expire_fragment("question-instance-metadata-#{record.id}")

    Question::POSSIBLE_SORTS.keys.each do |sort|
      expire_fragment("question-instance-index-#{record.id}-true-#{sort}")
      expire_fragment("question-instance-index-#{record.id}-false-#{sort}")
    end

    expire_fragment('question-instance-list')
    expire_action("updated-at-#{record.id}")
    expire_action("last-updated-question-#{record.id}")
  end

  def expire_question(record)
    ids_to_expire = [record.id, record.ancestors_ids].flatten

    ids_to_expire.each do |question_id|
      expire_fragment("question-detail-view-#{question_id}")
      expire_fragment("question-reply-detail-view-#{question_id}")
    end
  end

  def notify_private(record)
    if record.changed.include?("public") && record.public == false
      record.barcode.each do |barcode_tick|
        if barcode_tick[:title].match(/^Added to playlist/)
          playlist_id = barcode_tick[:link].gsub("/playlists/", '')
          playlist = Playlist.find(playlist_id)
          if playlist.user != record.user
            Notifier.deliver_item_made_private(playlist, record)
          end
        end
      end
    end
  end

  def notify_destroy(record)
    record.collages.each do |collage|
      Notifier.deliver_item_destroyed(collage, record)
    end
  end
end
