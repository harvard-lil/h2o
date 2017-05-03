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
		CaseCitation.all.joins(:case).where(case_citations: { volume: kase['volume'], 
			reporter: kase['reporter_abbreviation'], page: kase['page']  }, cases: { short_name: kase["name_abbreviation"]}).any?	
	end
end