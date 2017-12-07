class SearchesController < ApplicationController
  PER_PAGE = 10
  layout 'main'

  before_action :read_page

  def show
    @query = params[:q].present? ? params[:q] : '*'
    @type = params[:type] || 'casebooks'

    ungrouped_results = search_query(@query)
    @results = type_groups(ungrouped_results)

    @authors = build_filter(ungrouped_results.facet(:attribution).rows)
    @school_filters = build_filter(ungrouped_results.facet(:affiliation).rows)
    @paginated_group = paginate_group(@results[@type.to_sym])

    if params[:partial] #adding resource to a casebook
      render partial: 'results', layout: false, locals: {paginated_group: @paginated_group}
    end
  end

  def index
    @type = params[:type] || 'casebooks'

    ungrouped_results = search_query('*')
    @results = type_groups(ungrouped_results)
    casebook_results = @results[:casebooks]

    @authors = build_filter(ungrouped_results.facet(:attribution).rows)
    @school_filters = build_filter(ungrouped_results.facet(:affiliation).rows)

    @paginated_group = paginate_group(casebook_results)

    render 'searches/show'
  end

  private

  def build_filter(rows)
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

      any_of do
        with :public, true
        if current_user.present?
          with :owner_ids, current_user.id
        end
      end

      with :attribution, params[:author] if params[:author].present?
      with :affiliation, params[:school] if params[:school].present?

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

  def paginate_group(group)
    WillPaginate::Collection.create(@page, PER_PAGE, group.try(:total) || 0) do |pager|
       pager.replace(group.try(:results) || [])
    end
  end

  def read_page
    @page = (params[:page] || 1).to_i
  end
end
