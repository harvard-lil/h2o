require 'application_system_test_case'
require 'minitest/mock'

class CaseFinderSystemTest < ApplicationSystemTestCase
	describe 'as a logged in user' do
		scenario 'search for a case by name, view results and download a selected case' do
			sign_in user = users(:verified_professor)

			case_name = 'Comer v. Titan Tool, Inc.'
			case_citation = '875 F. Supp. 255'
			case_metadata = { 'slug' => 'comer-v-titan-tool-inc-2293' }
			query_params = { name: case_name, citation: case_citation }

			sign_in users(:student_user)
			visit new_case_finder_path

			fill_in 'Name', with: case_name
			fill_in 'Citation', with: case_citation

			stub_request(:get, "https://capapi.org/api/v1/cases/?#{query_params.to_query}&format=json").
				to_return(status: 200, body: new_case_search_response_body.to_json, 
					headers: {'Content-Type' => 'application/json'})

			click_button 'Search'

			assert_content case_name

			choose "case"

			stub_request(:get, "https://capapi.org/api/v1/cases/#{case_metadata["slug"]}/?type=download&max=1").
				with( headers: { "Authorization" => "Token #{H2o::Application.config.cap_api_key}"  }, query: { "type" => "download" }).
				to_return(status: 200, body: case_download_response_body, 
					headers: {'Content-Type' => 'application/xml'})

			click_button 'Download new case'

			assert_content 'Import successful'
		end

		scenario 'can see an error message when there is a failed case download' do
			sign_in user = users(:verified_professor)

			case_name = 'Comer v. Titan Tool, Inc.'
			case_citation = '875 F. Supp. 255'
			case_metadata = { 'slug' => 'comer-v-titan-tool-inc-2293' }
			query_params = { name: case_name, citation: case_citation }

			sign_in users(:student_user)
			visit new_case_finder_path

			fill_in 'Name', with: case_name
			fill_in 'Citation', with: case_citation

			stub_request(:get, "https://capapi.org/api/v1/cases/?#{query_params.to_query}&format=json").
				to_return(status: 200, body: new_case_search_response_body.to_json, 
					headers: {'Content-Type' => 'application/json'})

			click_button 'Search'

			assert_content case_name

			choose "case"

			stub_request(:get, "https://capapi.org/api/v1/cases/#{case_metadata["slug"]}/?type=download&max=1").
				with( headers: { "Authorization" => "Token #{H2o::Application.config.cap_api_key}"  }, query: { "type" => "download" }).
				to_return(status: 500)

			click_button 'Download new case'

			assert_content 'Case import failed'
		end
	end
end