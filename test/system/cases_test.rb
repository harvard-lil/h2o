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

      assert_content "Case #{search_label} in the Haystack"
      click_link "Case #{search_label} in the Haystack"

      assert_content "This is haystack case labeled #{search_label}"

      # Can't find a private case!
      # TODO: You really should be able to find a private case that belongs to you.
    end

    scenario 'reading a case' do
      public_case = cases :public_case_1
      visit case_path(public_case)

      assert_content public_case.full_name
      # assert_content public_case.author
      assert_content public_case.content
      # assert_content public_case.case_jurisdiction.name

      # annotations are visible
    end
  end
end
