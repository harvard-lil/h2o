class CaseFinder < ApplicationRecord
	CASE_FIELDS = ["name", "name_abbreviation", "url", "jurisdiction_id", 
		"jurisdiction_name", "docket_number", "decisiondate_original",
		"court_name", "court_id"]
end