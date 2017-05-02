module H2o::Test::Helpers::CaseFinderData
	def new_case_search_response_body
		{ 'results'=> 
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

	def case_params
		{"id"=>621573, "slug"=>"comer-v-titan-tool-inc-2293", 
			"url"=>"https://capapi.org/api/v1/cases/comer-v-titan-tool-inc-2293/?format=json", 
			"name"=>"Delores A. COMER and Patricia V. Edelson, Individually and as Personal Representatives and 
				Co-Administrators of the Estate of Michael T. Comer, Deceased, Plaintiffs, v. TITAN TOOL, INC., 
				Defendant; TITAN TOOL, INC., Third-Party Plaintiff, v. ROCK & WATERSCAPE SYSTEMS, INC., Third-Party Defendant", 
			"name_abbreviation"=>"Comer v. Titan Tool, Inc.", 
			"citation"=>"875 F. Supp. 255", 
			"firstpage"=>255, 
			"lastpage"=>260, 
			"jurisdiction"=>"https://capapi.org/api/v1/jurisdictions/1/?format=json", 
			"jurisdiction_name"=>"United States", 
			"jurisdiction_id"=>1, 
			"docketnumber"=>"No. 93 Civ. 1066 (RWS)", 
			"decisiondate_original"=>"1995-02-17", 
			"court"=>"https://capapi.org/api/v1/courts/60/?format=json", 
			"court_name"=>"United States District Court for the Southern District of New York", 
			"court_id"=>60, 
			"reporter"=>"https://capapi.org/api/v1/reporters/982/?format=json", 
			"reporter_name"=>"Federal Supplement", 
			"reporter_id"=>982, 
			"volume"=>875}
	end
end