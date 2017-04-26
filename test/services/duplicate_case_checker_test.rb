require 'application_system_test_case'

class DuplicateCaseCheckerTest < ApplicationSystemTestCase
	scenario 'deletes duplicate cases from a hash' do
		duplicate_case = cases(:case_with_citation)
		duplicate_citation = duplicate_case.case_citations.first

		puts "!(*@)!(*@)!(*@"
		puts duplicate_citation.to_s

		cases = [{'id'=>621573,
	    'name_abbreviation'=>'Comer v. Titan Tool, Inc.',
	    'citation'=>'875 F. Supp. 255'},
	    {'id'=>duplicate_case.id,
	    	'name_abbreviation'=>duplicate_case.short_name,
	    	'citation'=>duplicate_citation.display_name}] 

	  checked_cases = DuplicateCaseChecker.perform(cases)

	  assert_equal(1, checked_cases.count)
	end
end