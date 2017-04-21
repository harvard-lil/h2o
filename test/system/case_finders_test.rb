require 'application_system_test_case'

class CaseFinderSystemTest < ApplicationSystemTestCase
	describe 'as a logged in user' do
		scenario 'search for a case by name and see results' do
			case_name = 'Comer v. Titan Tool, Inc.'
			case_citation = '875 F. Supp. 255'
			query_params = { name: case_name, citation: case_citation }

			sign_in users(:student_user)
			visit new_case_finder_path

			fill_in 'Name', with: case_name
			fill_in 'Citation', with: case_citation

			stub_request(:get, "https://capapi.org/api/v1/cases/?#{query_params.to_query}&format=json").
				to_return(status: 200, body: response_body.to_json, headers: {'Content-Type' => 'application/json'})


			click_button 'Search'

			assert_content case_name
		end

		def response_body
			body = { 'results'=> 
				[{'id'=>621573,
		    'slug'=>'comer-v-titan-tool-inc-2293',
		    'url'=>'https://capapi.org/api/v1/cases/comer-v-titan-tool-inc-2293/?format=json',
		    'name'=>
		     'Delores A. COMER and Patricia V. Edelson, Individually and as Personal Representatives and Co-Administrators of the Estate of Michael T. Comer, Deceased, Plaintiffs, v. TITAN TOOL, INC., Defendant; TITAN TOOL, INC., Third-Party Plaintiff, v. ROCK & WATERSCAPE SYSTEMS, INC., Third-Party Defendant',
		    'name_abbreviation'=>'Comer v. Titan Tool, Inc.',
		    'citation'=>'875 F. Supp. 255',
		    'firstpage'=>255,
		    'lastpage'=>260,
		    'jurisdiction'=>'https://capapi.org/api/v1/jurisdictions/1/?format=json',
		    'jurisdiction_name'=>'United States',
		    'jurisdiction_id'=>1,
		    'docketnumber'=>'No. 93 Civ. 1066 (RWS)',
		    'decisiondate_original'=>'1995-02-17',
		    'court'=>'https://capapi.org/api/v1/courts/60/?format=json',
		    'court_name'=>'United States District Court for the Southern District of New York',
		    'court_id'=>60,
		    'reporter'=>'https://capapi.org/api/v1/reporters/982/?format=json',
		    'reporter_name'=>'Federal Supplement',
		    'reporter_id'=>982,
		    'volume'=>875}] }
		end
	end
end