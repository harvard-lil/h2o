class DuplicateCaseChecker
	def self.perform(cases)
		new(cases).perform
	end

	def initialize(cases)
		@cases = cases
	end

	def perform
    cases.take(10).each do |kase|
    	full_citation = kase["citation"]

    	volume = full_citation.scan(/[0-9]+/).first
    	reporter = full_citation.scan(/[A-Z].*(?<![0-9])/).first.chomp(' ')
    	page = full_citation.scan(/[0-9]+/).last


    	######### Make this join work.... case#short_name
    	if CaseCitation.where({ volume: volume, reporter: reporter, page: page }).joins(:case).exists?
    		puts 'it exists and is deleting'
    		cases.delete(kase)
    	end

    	#

    end
    cases
	end

	private

	attr_reader :cases
end