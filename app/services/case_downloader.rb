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
    @docket_number = case_metadata["docketnumber"]
    @volume = case_metadata["volume"]
    @reporter = case_metadata["reporter_name"]
    @page = case_metadata["firstpage"]
  end

  def perform
    response = make_api_request

    if response.code == 200
      case_content = unzip_response(response)
      save_case(case_content)
    else
      log_failure(response)
      false
    end
  end

  private

  attr_reader :current_user, :case_metadata, :slug, :short_name, :full_name, 
    :decision_date, :case_jurisdiction_id, :docket_number, :volume, :reporter, :page

  def make_api_request
    HTTParty.get(
      "https://capapi.org/api/v1/cases/#{slug}/?type=download&max=1",
      query: { "type" => "download" },
      headers: { "Authorization" => "Token #{H2o::Application.config.cap_api_key}" }
    )
  end

  def log_failure(options = {})
    Notifier.case_import_failure(current_user, case_metadata, options).deliver
  end

  def unzip_response(response)
    entry = Zip::InputStream.open(StringIO.new(response.body)).get_next_entry
    entry.get_input_stream.read
  end

  def save_case(case_content)
    new_case = Case.create(short_name: short_name, full_name: full_name, decision_date: decision_date, 
                           case_jurisdiction_id: case_jurisdiction_id, user_id: current_user.id, 
                           content: case_content, public: true)
    new_case_citation = CaseCitation.create(case_id: new_case.id, volume: volume, reporter: reporter, page: page)
    new_case_docket_number = CaseDocketNumber.create(case_id: new_case.id, docket_number: docket_number)

    if new_case.valid? && new_case_citation.valid? && new_case_docket_number.valid?
      true
    else
      log_failure
      false
    end
  end
end
