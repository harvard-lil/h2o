require 'application_system_test_case'
require 'minitest/mock'

class CapApiImportSystemTest < ApplicationSystemTestCase
  describe 'as a logged in user' do
    before do
      @case_name = 'Comer v. Titan Tool, Inc.'
      @case_citation = '875 F. Supp. 255'
      @case_metadata = { 'slug' => 'comer-v-titan-tool-inc-2293' }
      @query_params = { name: @case_name, citation: @case_citation }
    end

    scenario 'search for a case by name, view results and download a selected case' do
      skip "missing db schema"
      sign_in users(:verified_professor)

      visit new_cap_api_import_path

      fill_in 'Name', with: @case_name
      fill_in 'Citation', with: @case_citation

      stub_case_search(@query_params)

      click_button 'Search'

      assert_content @case_name

      choose "case"

      stub_case_import_from_cap_api(@case_metadata)

      click_button 'Download new case'

      assert_content 'Import successful'
    end

    scenario 'can see an error message when there is a failed case download' do
      skip "missing db schema"
      sign_in user = users(:verified_professor)

      visit new_cap_api_import_path

      fill_in 'Name', with: @case_name
      fill_in 'Citation', with: @case_citation

      stub_case_search(@query_params)

      click_button 'Search'

      assert_content @case_name

      choose "case"

      stub_case_import_from_cap_api_failed_attempt(@case_metadata)

      click_button 'Download new case'

      assert_content 'Case import failed'
    end
  end
end
