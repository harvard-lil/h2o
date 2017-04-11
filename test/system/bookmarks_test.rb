require 'application_system_test_case'

class BookmarkSystemTest < ApplicationSystemTestCase
	describe 'as a signed in user' do
		before do
      @user = users(:student_user)
      sign_in(@user)
     end

		scenario 'bookmarked playlists show up on a user\'s dashboard', js: true, solr: true do
      playlist = playlists(:public_playlist_1)
			visit playlist_path playlist

			click_link "Bookmark #{playlist.name}"

			visit user_path @user

			assert_content playlist.name
		end

		scenario 'dynamically bookmark and unbookmark a playlist', js: true, solr: true do
			playlist = playlists(:student_playlist)

			visit user_path @user

			find("li.listitem#{playlist.id}").hover

			click_link 'BOOKMARK'

			assert_content 'UN-BOOKMARK'

			click_link 'UN-BOOKMARK'

			assert_content 'BOOKMARK'
		end

		scenario 'bookmarked content appears in the bookmark list', js: true, solr: true do
			collage = collages(:collage_one)
			visit user_path @user

			find("li.listitem#{collage.id}").hover
			click_link 'BOOKMARK'

			assert_content 'UN-BOOKMARK'

			reload_page

			within('div#bookmarks_panel ul#results_bookmarks') do
				assert_content collage.name
			end
		end
	end
end
