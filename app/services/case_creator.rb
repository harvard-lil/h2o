require 'zip'

class CaseCreator
	def self.perform(api_output, case_metadata)
		new(api_output, case_metadata).perform
	end

	def initialize(api_output, case_metadata)
		@api_output = api_output
		@short_name = case_metadata["name_abbreviation"]
		@full_name = case_metadata["name"]
		@decision_date = case_metadata["decisiondate_original"]
		@case_jurisdiction_id = case_metadata["jurisdiction_id"]
		@user_id = case_metadata["user_id"]
	end

	def perform
		entry = Zip::InputStream.open(StringIO.new(@api_output)).get_next_entry
    case_content = entry.get_input_stream.read
    new_case = Case.new(short_name: @short_name, full_name: @full_name, decision_date: @decision_date, 
    											 case_jurisdiction_id: @case_jurisdiction_id, user_id: @user_id, 
    											 content: case_content, public: true)
		new_case.save
    # save citation
    # does this surface errors
	end

	private

	attr_reader :slug, :short_name, :full_name, :decision_date, :case_jurisdiction_id

end
