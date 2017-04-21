class CapApiSearchResults
	def self.perform(search_params)
		new(search_params).perform
	end

	def initialize(search_params)
		@citation = search_params[:citation]
		@name = search_params[:name]
	end

	def perform
		query_params = { 'name' => @name, 'citation' => @citation }

	  response = HTTParty.get("https://capapi.org/api/v1/cases/?#{query_params.to_query}&format=json")
    results = response["results"]

    DuplicateCaseCheck.perform(results)
	end

	private

	attr_reader :citation, :name
end
