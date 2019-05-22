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
      find('div.title', text: "Haystack Case (#{search_label})").click

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
      assert_content "Haystack Case (#{search_label})"
    end

    scenario 'reading a case', js: true do
      public_case = cases :public_case_1
      visit case_path(public_case)

      assert_content public_case.name_abbreviation
      assert_content Capybara::HTML(public_case.content).text

      # annotations are visible
    end
  end
end
