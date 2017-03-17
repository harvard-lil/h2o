require "test_helper"

feature 'playlists' do
  describe 'anonymous user' do
    scenario 'browsing a playlist' do
      public_playlist = playlists :public_playlist_1
      visit playlist_path(public_playlist)

      assert_content public_playlist.name
      assert_content public_playlist.user.attribution
      assert_content cases(:public_case_1).name
    end
  end
end
