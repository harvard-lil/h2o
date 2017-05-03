class CapApiSearchResults
	def self.perform(search_params)
		new(search_params).perform
	end

	def initialize(search_params)
		citation = search_params[:citation]
		case_name = search_params[:name]
		@query_params = {'name' => case_name, 'citation' => citation}
	end

	def perform
	  response = HTTParty.get("https://capapi.org/api/v1/cases/?#{query_params.to_query}&format=json")
    results = response["results"]

    return [] if results.empty?

    DuplicateCaseChecker.perform(results)
	end

	private

	attr_reader :citation, :name, :query_params
end
