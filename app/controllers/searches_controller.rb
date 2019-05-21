class SearchesController < ApplicationController
  PER_PAGE = 10
  layout 'main'

  before_action :read_page

  def show
    @query = params[:q]
    @type = params[:type] || 'casebooks'
    @page_title = I18n.t 'content.titles.searches.show'

    if @type == 'cases' && citation?(@query) && params[:partial] #only query capapi in resource casebook modal
      @paginated_group = paginate_group(
        Capapi::Case.list(cite: @query,
                          limit: PER_PAGE,
                          offset: PER_PAGE * (@page - 1)))
    else
      q = params[:q].present? ? params[:q] : '*'

      ungrouped_results = search_query(q)
      @results = type_groups(ungrouped_results)

      @attributions = extract_filter_data_from_sunspot_object(ungrouped_results.facet(:attribution).rows)
      @affiliations = extract_filter_data_from_sunspot_object(ungrouped_results.facet(:affiliation).rows)
      @paginated_group = paginate_group(@results[@type.to_sym])
    end

    if params[:partial] #for adding resource casebook modal
      render partial: 'results', layout: false, locals: {paginated_group: @paginated_group}
    end
  end

  def index
    @type = params[:type] || 'casebooks'
    @page_title = I18n.t 'content.titles.searches.index'

    ungrouped_results = search_query('*')
    @results = type_groups(ungrouped_results)
    casebook_results = @results[:casebooks]

    @attributions = extract_filter_data_from_sunspot_object(ungrouped_results.facet(:attribution).rows)
    @affiliations = extract_filter_data_from_sunspot_object(ungrouped_results.facet(:affiliation).rows)

    @paginated_group = paginate_group(casebook_results)

    render 'searches/show'
  end

  private

  def extract_filter_data_from_sunspot_object(rows)
    values = []

    rows.each do |row|
      values << row.value.strip
    end

    values.uniq.sort.reject { |c| c.empty? }
  end

  def type_groups(results)
    groups = results.group(:klass).groups
    return {
      casebooks: groups.find {|r| r.value == 'Content::Casebook'},
      cases: groups.find {|r| r.value == 'Case'},
      users: groups.find {|r| r.value == 'User'}
    }
  end

  def search_query(query)
    page = @page
    Sunspot.search(Case, Content::Casebook, User) do
      keywords query

      with :public, true

      with :attribution, params[:author] if params[:author].present?
      with :affiliation, params[:school] if params[:school].present?

      with(:verified_professor).equal_to(true)

      facet(:attribution)
      facet(:affiliation)

      order_by (params[:sort] || 'display_name').to_sym
      group :klass do
        limit PER_PAGE
      end

      adjust_solr_params do |params|
        params['group.offset'] = (page - 1) * PER_PAGE
      end
    end
  end

  def browse_page
    ! params[:type].present?
  end

  def casebooks_tab
    params[:type].include?('casebooks')
  end

  def users_tab
    params[:type].include?('users')
  end

  def paginate_group(group)
    WillPaginate::Collection.create(@page, PER_PAGE, group.try(:count) || group.try(:total) || 0) do |pager|
       pager.replace(group.try(:results) || [])
    end
  end

  def read_page
    @page = (params[:page] || 1).to_i
  end

  private

  def citation? str
    /^\d+(\s|-).*(\s|-)\d+$/.match(str)
  end
end
