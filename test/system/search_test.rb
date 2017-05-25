require 'application_system_test_case'

class SearchSystemTest < ApplicationSystemTestCase
  describe 'as an anonymous user' do
    scenario 'listing models', solr: true, js: true do
      visit search_all_path

      within '#advanced-search-content' do
        click_link 'Text'
      end
      assert_content 'Public Text 1'
      assert_no_content 'Private Text 1'

      within '#advanced-search-content' do
        click_link 'Clear'
        click_link 'Case'
      end
      assert_content 'District Case 1'
      assert_no_content 'Private Case 1'

      within '#advanced-search-content' do
        click_link 'Clear'
        click_link 'Link'
      end
      assert_content "Long Prison Term Is Less So Thanks to Regrets by a Judge"
      assert_no_content 'Private Link 1'

      within '#advanced-search-content' do
        click_link 'Clear'
        click_link 'case_admin'
      end
      assert_content "District Case 1"
    end
  end
end
