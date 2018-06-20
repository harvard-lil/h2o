# Variables
casebook = Content::Casebook.find(17493)
resource = casebook.resources.find_by(ordinals: [1, 1, 1])
playlist = Migrate::Playlist.find(casebook.playlist_id)
section_1 = Migrate::Playlist.find(playlist.playlist_items.first.actual_object_id)
item = Migrate::Playlist.find(section_1.playlist_items.find_by(position: 1).actual_object_id).playlist_items.find_by(position: 1)
casebook_default = resource.resource
playlist_default = item.actual_object
reload! && response = VerifySinglePlaylist.verify()

justin_hughes_link = Default.find(5536)