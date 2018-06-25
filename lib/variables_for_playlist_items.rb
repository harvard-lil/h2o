# Variables
# only doing updated at on jan 3rd for now.... presumably they would have noticed? Cause now it just shows all changes and they could be purposeful
casebooks = Content::Casebook.where.not(playlist_id: nil).where(ancestry: nil).where(updated_at: DateTime.new(2018, 1, 3)..DateTime.new(2018, 1, 4))

casebook = Content::Casebook.find(17493)
VerifySinglePlaylist.verify(casebook.id)


mismatched = VerifySinglePlaylist.verify


