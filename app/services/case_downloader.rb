require 'zip'

class CaseDownloader
  def self.perform(current_user, case_metadata)
    new(current_user, case_metadata).perform
  end

  def initialize(current_user, case_metadata)
    @current_user = current_user
    @case_metadata = case_metadata
    @slug = case_metadata["slug"]
    @short_name = case_metadata["name_abbreviation"]
    @full_name = case_metadata["name"]
    @decision_date = case_metadata["decisiondate_original"]
    @case_jurisdiction_id = case_metadata["jurisdiction_id"]
  end

  def perform
    response = make_api_request

    if response.code == 200
      case_content = unzip_response(response)
      save_case(case_content)
    else
      log_failure
      false
    end
  end

  private

  attr_reader :current_user, :case_metadata, :slug, :short_name, :full_name, 
    :decision_date, :case_jurisdiction_id

  def make_api_request
    HTTParty.get(
      "https://capapi.org/api/v1/cases/#{slug}/?type=download&max=1",
      query: { "type" => "download" },
      headers: { "Authorization" => "Token #{H2o::Application.config.cap_api_key}" }
    )
  end

  def log_failure
    Notifier.case_import_failure(current_user, case_metadata)
  end

  def unzip_response(response)
    entry = Zip::InputStream.open(StringIO.new(response.body)).get_next_entry
    entry.get_input_stream.read
  end

  def save_case(case_content)
    Case.create(short_name: short_name, full_name: full_name, decision_date: decision_date, 
                           case_jurisdiction_id: case_jurisdiction_id, user_id: current_user.id, 
                           content: case_content, public: true)
     
    ### add save citation
    ## does this surface errors 
  end
end
