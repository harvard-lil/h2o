module BackfillCaseCitations
  class << self
    def fill
      Case.all.each do |kase|
        kase.update(primary_case_citation: kase.case_citations.first)
      end
    end
  end
end
