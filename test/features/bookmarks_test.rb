require "test_helper"

feature 'bookmarks' do
	describe 'as a signed in user' do
		scenario 'bookmark and unbookmark a playlist', solr: true, js: true do
			skip
			## Not sure if this is needed anymore
			# page.driver.set_cookie('bookmarks', '%5B%5D')
      user = users(:student_user)
      sign_in(user)

      playlist = playlists(:public_playlist_1)
			visit playlist_path playlist

			click_link "Bookmark #{playlist.name}"

			### TODO click_link should trigger event itself
			execute_script("h2o_global.observeBookmarkControls();")

			find_link "Unbookmark #{playlist.name}"	

			visit user_path user
			assert_content 'Bookmarks' 
			assert_content playlist.name

			click_link 'UN-BOOKMARK'

			refute_content @playlist.name
		end
	end
end