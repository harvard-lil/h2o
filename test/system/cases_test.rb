require 'application_system_test_case'

class CaseSystemTest < ApplicationSystemTestCase
  describe 'as an anonymous user' do
    scenario 'browsing cases' do
      # public cases are visible
      # non-public cases are not visible
    end

    scenario 'searching for a case', solr: true do
      visit search_all_path
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
    scenario 'requesting a case' do
      sign_in user = users(:verified_student)
      visit cases_path
      click_link 'REQUEST CASE'

      fill_in 'Full name', with: 'Test Request'
      fill_in 'Decision date', with: '2017-01-01'
      fill_in 'Author', with: 'Test Author'
      fill_in 'Bluebook citation', with: 'Test citation'
      fill_in 'Docket number', with: 'docket.1'
      fill_in 'Volume', with: 'v.1'
      fill_in 'Reporter', with: 'Test reporter'
      fill_in 'Page', with: 'page.1'

      select CaseJurisdiction.first.name, from: 'Case jurisdiction'

      click_button 'Submit Case Request'
      assert_content "Case Request was successfully created."
    end

  end
  describe 'as a case administrator' do
    before do
      sign_in @user = users(:case_admin)
    end

    scenario 'adding a case for a request', js: true, solr: true do
      skip 'User page WIP'
      visit user_path @user
      assert_content 'Case Request 1'
      find('.create-case-from-request', visible: false).trigger('click')
      assert_content 'Add a new Case'
      fill_in 'Short name', with: 'Requested Case Name'
      execute_script "tinyMCE.activeEditor.setContent('#{'This is the case that was requested.'}');"

      click_link 'CREATE A NEW CASE JURISDICTION'
      assert_content 'Create a Case Jurisdiction'
      fill_in 'Name', with: 'test jurisdiction'
      fill_in 'Abbreviation', with: 'TJ-1'
      click_button 'Submit'
      select 'test jurisdiction', from: 'Case jurisdiction'

      click_button 'SAVE'

      assert_content 'Case was successfully created. It must be approved before it is visible.'
      new_case = Case.last

      visit user_path @user

      within '#results_pending_cases' do
        assert_content new_case.name
        within ".listitem#{new_case.id}" do
          click_link 'APPROVE'
        end
        assert_no_content new_case.name
      end

      visit user_path @user
      within '#results_set' do
        assert_content new_case.name
      end
    end

    scenario 'rejecting a case a request', js: true, solr: true do
      skip 'User page WIP'
      visit user_path @user
      assert_content 'Case Request 1'
      within '#results_case_requests' do
        click_link 'DELETE'
        assert_content 'Are you sure you want to delete this item?'
        click_link 'YES'
      end

      visit user_path @user
      assert_no_content 'Case Request 1'
    end

    scenario 'creating a case jurisdiction' do
      visit new_case_jurisdiction_path

    end
  end
end
