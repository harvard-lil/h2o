class DuplicateCaseChecker
	def self.perform(cases)
		new(cases).perform
	end

	def initialize(cases)
		@cases = cases
	end

	def perform
		cases.reject { |kase| case_already_exists?(kase) }
	end

	private

	attr_reader :cases

	def case_already_exists?(kase)
		full_citation = kase["citation"]
  	volume = full_citation.scan(/[0-9]+/).first
  	reporter = full_citation.scan(/[A-Z].*(?<![0-9])/).first.chomp(' ')
  	page = full_citation.scan(/[0-9]+/).last

		CaseCitation.all.joins(:case).where(case_citations: { volume: volume, reporter: reporter, page: page  }, cases: { short_name:  kase["name_abbreviation"]}).any?	
	end
end