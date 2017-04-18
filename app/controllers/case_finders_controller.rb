require 'zip'

class CaseFindersController < BaseController
  protect_from_forgery unless: -> { request.format.json? }

  def new
    if params[:case_finder]
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
    end
  end

  def download
    begin 
      cap_case_attrs = eval params[:case]

      response = HTTParty.get("https://capapi.org/api/v1/cases/#{cap_case_attrs["slug"]}/?type=download&max=1", 
          query: { "type" => "download" },
          headers: { "Authorization" => "Token 2c62c54b47e507b2eee20a70f29f1b4ae0ccd1a3" }
          # headers: { "Authorization" => "Token #{H2o::Application.config.cap_api_key}" }
      )

      new_case = import_case(cap_case_attrs, response.body)
      redirect_to case_path(new_case)

    rescue => e
      Notifier.case_import_failure(current_user, cap_case_attrs)
      flash[:error] = 'Case import failed'
      redirect_to new_case_finder_path
    end
  end

  private

  def import_case_params
    params.require(:case_finder).permit(
        :name, :name_abbreviation, :url, :jurisdiction_id, :jurisdiction_name, 
        :docket_number, :decisiondate_original, :court_name, :court_id, :reporter_name, 
        :reporter_id, :volume, :citation, :firstpage, :lastpage
    )
  end

  def import_case(cap_case_attrs, input)
    entry = Zip::InputStream.open(StringIO.new(input)).get_next_entry
    case_content = entry.get_input_stream.read
    new_case = Case.create(full_name: cap_case_attrs["name"], 
        decision_date: cap_case_attrs["decisiondate_original"], case_jurisdiction_id: cap_case_attrs["jurisdiction_id"], 
        content: case_content, user_id: current_user.id, created_via_import: true, public: true)
  end
end