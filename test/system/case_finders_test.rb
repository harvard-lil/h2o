require 'application_system_test_case'
require 'minitest/mock'

class CaseFinderSystemTest < ApplicationSystemTestCase
	describe 'as a logged in user' do
		before do
			@case_name = 'Comer v. Titan Tool, Inc.'
			@case_citation = '875 F. Supp. 255'
			@case_metadata = { 'slug' => 'comer-v-titan-tool-inc-2293' }
			@query_params = { name: @case_name, citation: @case_citation }
		end

		scenario 'search for a case by name, view results and download a selected case' do
			sign_in user = users(:verified_professor)

			sign_in users(:student_user)
			visit new_case_finder_path

			fill_in 'Name', with: @case_name
			fill_in 'Citation', with: @case_citation

			search_for_cases(@query_params)

			click_button 'Search'

			assert_content @case_name

			choose "case"

			download_case(@case_metadata)

			click_button 'Download new case'

			assert_content 'Import successful'
		end

		scenario 'can see an error message when there is a failed case download' do
			sign_in user = users(:verified_professor)

			sign_in users(:student_user)
			visit new_case_finder_path

			fill_in 'Name', with: @case_name
			fill_in 'Citation', with: @case_citation

			search_for_cases(@query_params)

			click_button 'Search'

			assert_content @case_name

			choose "case"

			download_case_failed_attempt(@case_metadata)

			click_button 'Download new case'

			assert_content 'Case import failed'
		end
	end
end