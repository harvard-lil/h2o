class SearchFilterBuilder
  attr_reader :type, :results, :author_params, :school_params

  def self.perform(params)
    new(params).perform
  end

  def initialize(params)
    @type = params[:type]
    @results = params[:results]
    @author_params = params[:author_params]
    @school_params = params[:school_params]
  end

  def perform
    authors = []
    schools = []

    if results
      results_group = results.try(:results)
      results_group.map do |result|
        if type == 'casebooks'
          authors.push result.owner unless authors.include?(result.owner)
          schools.push result.owner&.affiliation unless schools.include?(result.owner&.affiliation)
        elsif type == 'users'
          schools.push result.affiliation unless schools.include?(result.affiliation)
        end
      end
    else
      authors.push User.find(author_params) if author_params.present?
      schools.push school_params if school_params.present?
    end

    { authors: authors.compact, schools: schools.compact }
  end
end