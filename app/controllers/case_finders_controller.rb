require 'zip'

class CaseFindersController < BaseController
  protect_from_forgery unless: -> { request.format.json? }

  def new
    if case_search_initiated
      @cases = CapApiSearchResults.perform(case_finder_params)
    end
  end

  def create
    if case_imported
      flash[:notice] = 'Import succesful'
    else 
      Notifier.case_import_failure(current_user, case_params)
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

  def case_params
    JSON.parse(params[:case])
  end

   def case_imported
    response = HTTParty.get("https://capapi.org/api/v1/cases/#{case_params["slug"]}/?type=download&max=1",
                            query: { "type" => "download" },
                            headers: { "Authorization" => "Token 2c62c54b47e507b2eee20a70f29f1b4ae0ccd1a3" }
                            # headers: { "Authorization" => "Token #{H2o::Application.config.cap_api_key}" }
                            )
    download_case_content(response.body)
  end

  def download_case_content(cap_api_output)
    entry = Zip::InputStream.open(StringIO.new(cap_api_output)).get_next_entry
    case_content = entry.get_input_stream.read
    puts "about to create case"
    # short_name: case_params["name_abbreviation"]
    new_case = Case.new(full_name: case_params["name"],
                           decision_date: case_params["decisiondate_original"], case_jurisdiction_id: case_params["jurisdiction_id"],
                           content: case_content, user_id: current_user.id, created_via_import: true, public: true)
    new_case.save
  end
end
