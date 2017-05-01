class CaseFindersController < BaseController
  protect_from_forgery unless: -> { request.format.json? } ### is this necessary?

  def new
    if case_search_initiated
      @cases = CapApiSearchResults.perform(case_finder_params)
    end
  end

  def create
    if case_downloaded
      flash[:notice] = 'Import successful'
      redirect_back(fallback_location: new_case_finder_path)
    else 
      Notifier.case_import_failure(current_user, case_metadata)
      flash[:error] = 'Case import failed'
      redirect_back(fallback_location: new_case_finder_path)
    end
  end

  private

  def case_finder_params
    params.require(:case_finder).permit(:name, :citation)
  end

  def case_search_initiated
    params[:case_finder]
  end

  def case_metadata
    metadata = JSON.parse(params[:case])
    metadata['user_id'] = current_user.id
    metadata
  end

   def case_downloaded
    response = HTTParty.get("https://capapi.org/api/v1/cases/#{case_metadata["slug"]}/?type=download&max=1",
                            query: { "type" => "download" },
                            headers: { "Authorization" => "Token #{H2o::Application.config.cap_api_key}" }
                            )

    if response.code == 200
      CaseDownloader.perform(response.body, case_metadata)
    else
      false
    end
  end
end
