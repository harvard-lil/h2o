require 'application_system_test_case'

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
      @student_playlist = playlists(:student_playlist)
      sign_in(@user)
    end

    scenario 'can see private playlists they made', solr: true do
      # if a user makes a private playlist it doesn't
      # show up in their search results
      # they can only see it on their dashboard

      visit user_path(@user.id)
      assert_content @student_playlist.name
    end

    scenario 'creating a playlist', solr: true, js: true do
      visit root_path
      click_link 'CREATE'
      click_link 'Playlist'

      fill_in 'Name', with: 'Name of a new playlist!'
      # find('#playlist_description').set('This is a description about a playlist')
      # This is the pattern to edit inside the rich text box:
      within_frame find('#playlist_description_input .mce-tinymce iframe', visible: false) do
        find('body').set 'This is a description about a playlist'
      end

      ## I have no idea how the submit button is on this form.
      # unlike the defaults/link form this form doesn't change
      # the url. This button must be added with jquery.. I don't
      # see where it's added. Either way the button doesn't show up
      # in the body

      # I am not sure why clicking 'Submit' doesn't do this, but this works...
      execute_script 'h2o_global.submitGenericNode();'
      # click_button 'Submit'

      assert_content "Name of a new playlist! by #{@user.attribution}"
    end

    scenario 'cloning a playlist', solr: true, js: true do
      visit playlist_path(@public_playlist.id)

      click_link 'Clone Playlist'

      fill_in 'Name*', with: "Clone of #{@public_playlist.name}"
      click_button 'Submit'

      assert_content 'The system is cloning the playlist and every item
        in the playlist. You will be emailed when the process has completed.'
    end

    scenario 'editing a playlist', solr: true, js: true do
      public_case = cases(:public_case_1)
      link = defaults(:link_one)
      text_block = text_blocks(:public_text_to_annotate)

      visit "/playlists/#{@student_playlist.id}"
      playlist_list = page.find('.main_playlist')

      # edit playlist information
      click_link 'EDIT PLAYLIST INFORMATION'
      fill_in 'Name', with: 'New name'
      click_button 'Submit'

      assert_content "New name by #{@user.attribution}"

      # adding cases
      fill_in 'add_item_term', with: "\"#{public_case.short_name}\"" # Use exact search to not pick up a bunch of cases
      click_link 'add_item_search'
      assert_content '1 Result' # Make sure to wait for results  before dragging
      simulate_drag "#listing_cases_#{public_case.id} .dd-handle", '.main_playlist' # custom drag handler that works with nesting library
      assert_content 'You may not edit name or description' # make sure to wait for drag to finish
      click_link 'SUBMIT'
      assert_content "2 #{public_case.short_name}" # passes!

      # adding texts
      fill_in 'add_item_term', with: "\"#{text_block.name}\""
      click_link 'add_item_search'
      fill_in 'add_item_term', with: ''
      assert_content "#{text_block.name}"
      simulate_drag "#listing_text_blocks_#{text_block.id} .dd-handle", '.main_playlist li:first-child'
      click_link 'SUBMIT'
      assert_content "2 #{text_block.name}" # passes!

      # adding links (in future, all "media" will be URLs)
      fill_in 'add_item_term', with: "\"#{link.name}\""
      click_link 'add_item_search'
      fill_in 'add_item_term', with: ''
      assert_content "#{link.name}"
      simulate_drag "#listing_defaults_#{link.id} .dd-handle", '.main_playlist li:first-child'
      click_link 'SUBMIT'
      assert_no_link 'SUBMIT'
      assert_content "2 Show/Hide More #{link.name}" # passes!

      # adding playlists
      fill_in 'add_item_term', with: "\"#{@public_playlist.name}\""
      click_link 'add_item_search'
      fill_in 'add_item_term', with: ""
      assert_content "\"#{@public_playlist.name}\""
      simulate_drag "#listing_playlists_#{@public_playlist.id} .dd-handle", '.main_playlist li:first-child'
      click_link 'SUBMIT'
      assert_content "2 Show/Hide More #{@public_playlist.name}" # passes!

      # reordering material
      assert_content "5 District Case 1"
      item_id = find('.main_playlist > ol > li.dd-item:last-child')[:id]
      simulate_drag "\##{item_id} .dd-handle", '.main_playlist > ol > li.dd-item:first-child'
      assert_content "1 District Case 1"

      # removing material
      playlist_item = @student_playlist.playlist_items.first
      assert_content playlist_item.name
      find("li.listitem#{playlist_item.id} a.delete-playlist-item").click
      click_link 'YES'

      refute_content playlist_item.name
    end
  end
end
