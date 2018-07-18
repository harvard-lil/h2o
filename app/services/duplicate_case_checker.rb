class DuplicateCaseChecker
  def self.perform(cases)
    new(cases).perform
  end

  def initialize(cases)
    @cases = cases
  end

  def perform
    cases.reject { |case_metadata| case_already_exists?(case_metadata) }
  end

  private

  attr_reader :cases

  def case_already_exists?(case_metadata)
    # TODO cache this query
    CaseCitation.all.joins(:case).where(case_citations: { volume: case_metadata['volume'], 
      reporter: case_metadata['reporter_abbreviation'], page: case_metadata['page']  }, cases: { name_abbreviation: case_metadata["name_abbreviation"]}).any? 
  end
end
