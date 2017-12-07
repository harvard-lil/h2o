class SearchFilterBuilder
  attr_reader :type, :results, :author_params, :school_params

  def self.perform(params)
    new(params).perform
  end

  def initialize(params)
    @type = params[:type]
    @results = params[:results]
    @school_params = params[:school_params]
  end

  def perform
    schools = []

    if results
      results_group = results.try(:results)
      results_group.map do |result|
        if type == 'casebooks'
          schools.push result.owner&.affiliation unless schools.include?(result.owner&.affiliation)
        elsif type == 'users'
          schools.push result.affiliation unless schools.include?(result.affiliation)
        end
      end
    else
      schools.push school_params if school_params.present?
    end

    { schools: schools.compact }
  end
end