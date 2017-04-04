require "test_helper"

feature 'bookmarks' do
	describe 'as a signed in user' do
		before do 
	    @user = users(:student_user)
      sign_in(@user)

      @playlist = playlists(:public_playlist_1)
			visit playlist_path @playlist
		end

		scenario 'bookmark and unbookmark a playlist', js: true do
			# there are two Bookmark Playlist links b/c of the quickbar
			find_all('a.bookmark-action').first.click

			click_link "#{@user.attribution} Dashboard"

			assert_content @playlist.name

			# playlist name shows up under bookmark section

			#click playlist name

			# unbookmark playlist 

			# assert some content
		end

		scenario 'cannot view another user\'s bookmarks' do
			# need playlist owned by student user 
			# playlist = playlists(:public_playlist_1)

		end
	end

	describe 'as an anonymous user' do
		scenario 'cannnot bookmark playlists' do
			# icon doesn't show up 
		end
	end
end