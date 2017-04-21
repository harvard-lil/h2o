class DuplicateCaseCheck
	def self.perform(cases)
		new(cases).perform
	end

	def initialize(cases)
		@cases = cases
	end

	def perform
    cases.take(10).each do |kase|
      if Case.where(short_name: kase["name_abbreviation"],
                    case_jurisdiction_id: kase["jurisdiction_id"]).exists?
        cases.delete(kase)
      end
    end
    cases
	end

	private

	attr_reader :cases
end