require "test_helper"

feature 'playlists' do
  describe 'anonymous user' do
    scenario 'browsing a playlist' do
      public_playlist = playlists :public_playlist_1
      visit playlist_path(public_playlist)

      assert_content public_playlist.name
      assert_content public_playlist.user.attribution
      assert_content cases(:public_case_1).name
      assert_content public_playlist.user.affiliation

    end
    scenario "can't edit a playlist", js: true do
      visit playlist_path(playlists :public_playlist_1)
      # binding.pry
      # TODO: This should not be done in javascript.
      assert_no_link "EDIT PLAYLIST INFORMATION"
    end
  end
end
