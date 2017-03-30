require "test_helper"

feature 'playlists' do
  before do
    @public_playlist = playlists(:public_playlist_1)
    @private_playlist = playlists(:private_playlist_1)
  end
  describe 'as an anonymous visitor' do

    scenario 'viewing a playlist', solr: true do
      visit playlist_path(@public_playlist)

      assert_content @public_playlist.name
      assert_content @public_playlist.user.attribution
      assert_content cases(:public_case_1).name
      assert_content cases(:public_case_2).name

      click_link "#{cases(:public_case_1).name}"
      go_back
      click_link "#{cases(:public_case_2).name}"
      go_back

      assert_content @public_playlist.name
      # follow link to cases/texts/media
    end
    scenario 'browsing playlists', solr: true do
      visit playlists_path

      assert_content @public_playlist.name
      refute_content @private_playlist.name

      # can see public playlists
      # can't see private playlists
    end
    scenario 'searching playlists', solr: true do
      visit root_path

      # search by title
      # can find public playlists
      # can't find private playlists
      fill_in 'Keywords', with: 'Playlist'
      page.submit find('form.search')

      assert_content @public_playlist.name
      refute_content @private_playlist.name

      # search by content
      fill_in 'Keywords', with: @private_playlist.playlist_items.first

      refute_content [@public_playlist.name, @private_playlist.name]
    end
  end
  describe 'as a registered user' do
    before do
      @user = users(:student_user)
      sign_in(@user)
    end

    scenario 'can see private playlists they made', solr: true do
      # if a user makes a private playlist it doesn't
      # show up in their search results
      # they can only see it on their dashboard

      visit user_path(@user.id)
      assert_content playlists(:student_playlist).name
    end

    scenario 'creating a playlist', solr: true, js: true do
      skip
      visit root_path
      click_link 'CREATE'
      click_link 'Playlist'

      fill_in 'Name', with: 'Name of a new playlist!'
      find('#playlist_description').set('This is a description about a playlist')

      ## I have no idea how the submit button is on this form. 
      # unlike the defaults/link form this form doesn't change
      # the url. This button must be added with jquery.. I don't
      # see where it's added. Either way the button doesn't show up
      # in the body

      click_button 'Submit'

      assert_content "Name of a new playlist! by #{@user.name}"

    end
    scenario 'cloning a playlist', solor: true, js: true do
      skip
      visit playlists_path
      assert_content playlists(:student_playlist).name




    end
    scenario 'editing a playlist', js: true do

      # adding cases
      # adding texts
      # adding links (in future, all "media" will be URLs)
      # adding playlists (?)
      # reordering material
      # removing material
    end
  end
end
