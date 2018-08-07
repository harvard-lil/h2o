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
    Case.where_citations_contains({volume: case_metadata['volume'].to_s,
                                   reporter: case_metadata['reporter_abbreviation'],
                                   page: case_metadata['page'].to_s })
      .where(name_abbreviation: case_metadata["name_abbreviation"]).any?
  end
end
