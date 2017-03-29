require 'application_system_test_case'

feature 'cases' do
  describe 'as an anonymous user' do
    scenario 'browsing cases' do
      # public cases are visible
      # non-public cases are not visible
    end

    scenario 'searching for a case', solr: true do
      visit root_path
      search_label = [*'XA'..'XZ'].sample
      fill_in 'Keywords', with: "Case #{search_label}"
      # click_link 'SEARCH' # TODO: This should not require JavaScript!
      page.submit find('form.search')

      assert_content "Search Results: Case #{search_label}"
      assert_content "1 Case Total"

      click_link "Haystack Case (#{search_label})"
      assert_content "This is haystack case labeled #{search_label}"

      # Can't find a private case!
      # TODO: You really should be able to find a private case that belongs to you.
      search_label = [*'YA'..'YZ'].sample
      fill_in 'Keywords', with: "Case #{search_label}"
      page.submit find('form.search')

      assert_content "Search Results: Case #{search_label}"
      assert_content "0 Results Total"

      # Simulate a case edit
      search_label = [*'XA'..'XZ'].sample
      cases(:"haystack_case_#{search_label}").update! short_name: "Updated Haystack Case (#{search_label})"
      Sunspot.commit # TODO: Test this properly

      fill_in 'Keywords', with: "Updated Haystack Case"
      page.submit find('form.search')

      assert_content "Search Results: Updated Haystack Case"
      assert_content "1 Case Total"
      assert_content "Updated Haystack Case (#{search_label})"
    end

    scenario 'reading a case' do
      public_case = cases :public_case_1
      visit case_path(public_case)

      assert_content public_case.short_name
      assert_content public_case.author
      assert_content public_case.content
      assert_content public_case.case_jurisdiction.name

      # annotations are visible
    end
  end
  describe 'as a registered user' do
    scenario 'browsing, searching, and reading cases' do
      # DRY stuff from above
      # can see private cases that belong to user
    end

    scenario 'annotating a case', js: true do
      # This is literally a copy-paste of the text annotation path... Makes one wonder
      sign_in user = users(:verified_student)
      visit case_path public_case = cases(:public_case_to_annotate)

      click_link 'Clone and Annotate'
      assert_xpath "//input[@value='#{public_case.short_name}']"

      # TODO: make mce tests more intuitive than this
      annotated_desc = "Test annotated case desc: #{random_token}"
      within_frame find('#collage_description_input .mce-tinymce iframe', visible: false) do
        find('body').set annotated_desc
      end

      click_button 'Submit'

      assert_link 'ANNOTATION DISPLAY'
      assert_content annotated_desc

      # TODO: make these buttons more accessible
      # TODO: Annotations sometimes take a very long time. wait: 3.seconds seems to work reliably

      # Highlighting
      select_text 'content to highlight'
      find('[title=highlight]').trigger 'click'
      click_link 'ffee00'
      click_link 'Save'
      find('.highlight-hex-ffee00').assert_text 'content to highlight'

      # Elision
      select_text 'content to elide'
      find('[title=hide]').trigger 'click'
      assert_content 'elided: [...];'

      # Replacement
      select_text 'content to replace'
      find('[title="replace text"]').trigger 'click'
      fill_in placeholder: 'Enter replacement text...', with: 'replacement content'
      click_link 'Save'
      assert_content 'replaced: [replacement content];'

      # Comments
      select_text 'content to comment'
      find('[title="annotate"]').trigger 'click'
      fill_in placeholder: 'Comments...', with: 'comment content'
      click_link 'Save'
      find('.icon.icon-adder-annotate', visible: true).click
      assert_content 'comment content'

      sleep 1.second # TODO: The JS is updating this on a setInterval.

      # Annotations are still visible when logged out
      click_link 'sign out'

      assert_link 'sign in'
      assert_content "#{public_case.short_name} by #{user.attribution}"

      find('.highlight-hex-ffee00').assert_text 'content to highlight'
      assert_content 'elided: [...];'
      assert_content 'replaced: [replacement content];'
      find('.icon.icon-adder-annotate', visible: true).click
      assert_content 'comment content'
    end

    scenario 'requesting a case for import' do

    end
  end
  describe 'as a case administrator' do
    scenario 'viewing case requests' do

    end
    scenario 'adding a case for a request' do

    end
    scenario 'rejecting a case request' do

    end
    scenario 'editing a case' do

    end
  end
end
