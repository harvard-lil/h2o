require 'application_system_test_case'

class CaseSystemTest < ApplicationSystemTestCase
  describe 'as an anonymous user' do
    scenario 'browsing cases' do
      # public cases are visible
      # non-public cases are not visible
    end

    scenario 'searching for a case', solr: true do
      visit search_path
      search_label = [*'XA'..'XZ'].sample
      fill_in 'q', with: "Case #{search_label}"
      page.submit find('form.search')

      assert_content "Cases (1)"
      click_link "Cases (1)"

      find('div.title', text: "Case #{search_label} in the Haystack").click

      # Can't find a private case!
      # TODO: You really should be able to find a private case that belongs to you.
      search_label = [*'YA'..'YZ'].sample
      fill_in 'q', with: "Case #{search_label}"
      page.submit find('form.search')

      assert_content "Cases (0)"

      # Simulate a case edit
      search_label = [*'XA'..'XZ'].sample
      cases(:"haystack_case_#{search_label}").update! name: "Updated Haystack Case (#{search_label})"
      Sunspot.commit # TODO: Test this properly

      fill_in 'q', with: "Updated Haystack Case"
      page.submit find('form.search')

      assert_content "Cases (1)"
      click_link "Cases (1)"
      assert_content "Updated Haystack Case (#{search_label})"
    end

    scenario 'reading a case' do
      public_case = cases :public_case_1
      visit case_path(public_case)

      assert_content public_case.name
      assert_content public_case.content

      # annotations are visible
    end
  end
  describe 'as a registered user' do
    scenario 'requesting a case' do
      SimpleCov.add_filter %w{app/controllers/case_requests_controller.rb}
      skip 'Case requests are disabled'

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
end
