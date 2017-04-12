require 'zip'

class CaseFindersController < BaseController
  protect_from_forgery unless: -> { request.format.json? }

  def new
  end

  def create
    params = {}
    CaseFinder::CASE_FIELDS.each do |field|
        if import_case_params[field].present?
            params[field] = import_case_params[field]
        end
    end

    response = HTTParty.get("https://capapi.org/api/v1/cases/?#{params.to_query}&format=json")
    @cases = response["results"]

    @cases.take(10).each do |kase|
        if Case.where(short_name: kase["name_abbreviation"], case_jurisdiction_id: kase["jurisdiction_id"]).exists?
            @cases.delete(kase)
        end
    end

    render :show
  end

  def download
    cap_token = params[:cap_token]
    cap_case = eval params[:case]

    response = HTTParty.get("https://capapi.org/api/v1/cases/#{cap_case["slug"]}/?type=download&max=1", 
        query: { "type" => "download" },
        headers: { "Authorization" => "Token #{cap_token}" }
    )

    input = response.body

    Zip::InputStream.open(StringIO.new(input)) do |io|
      while entry = io.get_next_entry
        kontent = entry.get_input_stream.read
        @new_case = Case.create(short_name: cap_case["name_abbreviation"], full_name: cap_case["name"], 
            decision_date: cap_case["decisiondate_original"], case_jurisdiction_id: cap_case["jurisdiction_id"], 
            content: kontent, user_id: current_user.id, created_via_import: true, public: true)
      end
    end

    redirect_to case_path(@new_case)
  end

  private

  def import_case_params
    params.require(:case_finder).permit(
        :name, :name_abbreviation, :url, :jurisdiction_id, :jurisdiction_name, 
        :docket_number, :decisiondate_original, :court_name, :court_id, :reporter_name, 
        :reporter_id, :volume, :citation, :firstpage, :lastpage
    )
  end
end
