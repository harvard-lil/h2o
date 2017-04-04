require "test_helper"

feature 'bookmarks' do
	describe 'as a signed in user' do
		before do 
	    user = users(:case_admin)
      sign_in(user)
		end

		scenario 'bookmark and unbookmark a playlist' do
			playlist = playlists(:public_playlist_1)

			visit playlist_path playlist


			# there are two Bookmark Playlist links b/c of the quickbar
			click_link '.icon-favorite-large'

			visit dashboard 

			# playlist name shows up under bookmark section

			#click playlist name

			# unbookmark playlist 

			# assert some content
		end

		scenario 'cannot view another user\'s bookmarks' do
			# need playlist owned by student user 
			# playlist = playlists(:public_playlist_1)

			visit playlist_path playlist


		end
	end

	describe 'as an anonymous user' do
		scenario 'cannnot bookmark playlists' do
			# icon doesn't show up 
		end
	end
end