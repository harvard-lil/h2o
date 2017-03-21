require "test_helper"

feature 'playlists' do
  describe 'as an anonymous visitor' do
    scenario 'viewing a playlist' do
      public_playlist = playlists :public_playlist_1
      visit playlist_path(public_playlist)

      assert_content public_playlist.name
      assert_content public_playlist.user.attribution
      assert_content cases(:public_case_1).name
      assert_content public_playlist.user.affiliation

      # follow link to cases/texts/media
    end
    scenario 'browsing playlists' do
      # can see public playlists
      # can't see private playlists
    end
    scenario 'searching playlists' do
      # can search by title or contents (?)
      # can find public playlists
      # can't find private playlists
    end
  end
  describe 'as a registered user' do
    scenario 'browsing, searching, and viewing playlists' do
      # DRY stuff from above
      # can see prvate playlists that belong to user
    end
    scenario 'creating a playlist' do
      skip
    end
    scenario 'cloning a playlist' do
      skip
    end
    scenario 'editing a playlist', js: true do
      skip
      # adding cases
      # adding texts
      # adding links (in future, all "media" will be URLs)
      # adding playlists (?)
      # reordering material
      # removing material
    end
  end
end
