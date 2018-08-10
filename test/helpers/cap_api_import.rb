module H2o::Test::Helpers::CapApiImport
  def stub_case_search(params)
    stub_request(:get, "https://capapi.org/api/v1/cases/?#{params.to_query}&format=json").
      to_return(status: 200, body: search_response_body.to_json,
                headers: {"Content-Type" => "application/json"})
  end

  def stub_case_search_with_no_results(params)
    stub_request(:get, "https://capapi.org/api/v1/cases/?#{params.to_query}&format=json").
      to_return(status: 200, body: { "results"=> [] }.to_json,
                headers: {"Content-Type" => "application/json"})
  end

  def stub_case_import_from_cap_api(metadata)
    stub_request(:get, "https://capapi.org/api/v1/cases/#{metadata["slug"]}/?type=download&max=1").
      with( headers: { "Authorization" => "Token #{H2o::Application.config.capapi_key}"  }, query: { "type" => "download" }).
      to_return(status: 200, body: File.read("test/fixtures/case_download.zip"), headers: {"Content-Type" => "application/xml"})
  end

  def stub_case_import_from_cap_api_failed_attempt(metadata)
    stub_request(:get, "https://capapi.org/api/v1/cases/#{metadata["slug"]}/?type=download&max=1").
      with( headers: { "Authorization" => "Token #{H2o::Application.config.capapi_key}"  }, query: { "type" => "download" }).
      to_return(status: 500)
  end

  def search_response_body
    { "results"=>
      [{"id"=>621573,
        "slug"=>"comer-v-titan-tool-inc-2293",
        "url"=>"https://capapi.org/api/v1/cases/comer-v-titan-tool-inc-2293/?format=json",
        "name"=>
        "Delores A. COMER and Patricia V. Edelson, Individually and as Personal Representatives and Co-Administrators of the Estate of Michael T. Comer, Deceased, Plaintiffs, v. TITAN TOOL, INC., Defendant; TITAN TOOL, INC., Third-Party Plaintiff, v. ROCK & WATERSCAPE SYSTEMS, INC., Third-Party Defendant",
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
        "reporter_abbreviation"=> "F. Supp.",
        "reporter_id"=>982,
        "volume"=>875}] }
  end

  def case_metadata
    {"id"=>621573, "slug"=>"comer-v-titan-tool-inc-2293",
     "url"=>"https://capapi.org/api/v1/cases/comer-v-titan-tool-inc-2293/?format=json",
     "name"=>"Delores A. COMER and Patricia V. Edelson, Individually and as Personal Representatives and Co-Administrators of the Estate of Michael T. Comer, Deceased, Plaintiffs, v. TITAN TOOL, INC., Defendant; TITAN TOOL, INC., Third-Party Plaintiff, v. ROCK & WATERSCAPE SYSTEMS, INC., Third-Party Defendant", 
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
     "reporter_abbreviation"=> "F. Supp.",
     "reporter_id"=>982,
     "volume"=>875}
  end

  def case_metadata_2
    {"id"=> 393783,
    "slug"=> "bates-v-united-states-4330",
    "url"=> "https://capapi.org/cases/bates-v-united-states-4330/",
    "name"=> "George W. BATES, Appellant, v. UNITED STATES of America, Appellee",
    "name_abbreviation"=> "Bates v. United States",
    "citation"=> "405 F.2d 1104",
    "firstpage"=> 1104,
    "lastpage"=> 1106,
    "jurisdiction"=> "https://capapi.org/jurisdictions/1/",
    "jurisdiction_name"=> "United States",
    "jurisdiction_id"=> 1,
    "docketnumber"=> "No. 21434",
    "decisiondate_original"=> "1968-12-13",
    "court"=> "https://capapi.org/courts/97/",
    "court_name"=>"United States Court of Appeals for the District of Columbia Circuit",
    "court_id"=> 97,
    "reporter"=>"https://capapi.org/reporters/980/",
    "reporter_name"=> "Federal Reporter 2d Series",
    "reporter_abbreviation"=> "F. 2d",
    "reporter_id"=> 980,
    "volume"=> 405}
  end

  def incomplete_case_metadata
    {"id"=>621573, "slug"=>"comer-v-titan-tool-inc-2293",
     "url"=>"https://capapi.org/api/v1/cases/comer-v-titan-tool-inc-2293/?format=json",
     "name"=>"Delores A. COMER and Patricia V. Edelson, Individually and as Personal Representatives and
        Co-Administrators of the Estate of Michael T. Comer, Deceased, Plaintiffs, v. TITAN TOOL, INC., 
        Defendant; TITAN TOOL, INC., Third-Party Plaintiff, v. ROCK & WATERSCAPE SYSTEMS, INC., Third-Party Defendant", 
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
     "reporter_abbreviation"=> "F. Supp.",
     "reporter_id"=>982,
     "volume"=>875}
  end

  def duplicate_case_metadata
    {"name_abbreviation"=>"Case With Citation",
      "volume"=>405,
      "reporter_abbreviation"=>"F .2d",
      "page"=>1104
   }
  end

  def search_result
    search_results = []
    search_results << case_metadata
  end

  def two_search_results 
    search_result << case_metadata_2
  end

  def search_results_with_duplicate
    search_results = []
    search_results << case_metadata
    search_results << duplicate_case_metadata
  end
end
