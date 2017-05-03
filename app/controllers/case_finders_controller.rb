class CaseFindersController < BaseController
  protect_from_forgery unless: -> { request.format.json? } ### is this necessary?

  def new
    if case_search_initiated?
      @cases = CapApiSearchResults.perform(case_search_params)
    end
  end

  def create
    if case_downloaded?
      flash[:notice] = "Import successful"
      redirect_back(fallback_location: new_case_finder_path)
    else
      flash[:error] = 'Case import failed'
      redirect_back(fallback_location: new_case_finder_path)
    end
  end

  private

  def case_search_params
    params.require(:case_finder).permit(:name, :citation)
  end

  def case_search_initiated?
    params[:case_finder].present?
  end

  def case_metadata
    JSON.parse(params[:case])
  end

  def case_downloaded?
    CaseDownloader.perform(current_user, case_metadata)
    ## TODO pass back new_case_id so that there can be a link to the new case
  end
end
