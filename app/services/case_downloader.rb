class CaseDownloader

  def initialize(current_user, case_metadata)
    @current_user = current_user
    @case_metadata = case_metadata
  end

  def download
    response = make_api_request

    if response.code == 200
      CaseCreator.perform(response.body, case_metadata)
    else
      log_failure
      false
    end
  end

  private

  def make_api_request
    HTTParty.get(
      "https://capapi.org/api/v1/cases/#{case_metadata["slug"]}/?type=download&max=1",
      query: { "type" => "download" },
      headers: { "Authorization" => "Token #{H2o::Application.config.cap_api_key}" }
    )
  end

  attr_reader :case_metadata, :current_user

  def log_failure
    Notifier.case_import_failure(current_user, case_metadata)
  end
end
