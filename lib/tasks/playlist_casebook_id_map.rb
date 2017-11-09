class PlaylistCasebookIdMap
  def build
    map = []

    Content::Casebook.find_each do |casebook|
      map << { "#{casebook.playlist_id}": casebook.id  }
    end

    map
  end
end