class SearchesController < ApplicationController
  PER_PAGE = 10
  layout 'main'

  before_action :read_page

  def show
    @authors = User.all 
    @schools = schools
    @query = params[:q]
    @type = params[:type] || 'casebooks'

    @results = if @query
      result_groups @query
    else
      result_groups '*'
    end

    @pagination = paginate_group @results[@type.to_sym]
    @authors = User.all

    if params[:partial]
      render partial: 'results', layout: false, locals: {pagination: @pagination}
    end
  end

  def index
    @authors = User.all
    @schools = schools
    @type = params[:type] || 'casebooks'
    @results = result_groups '*'
    @pagination = paginate_group @results[:casebooks]
    render 'searches/show'
  end

  private

  def paginate_group group
    WillPaginate::Collection.create(@page, PER_PAGE, group.try(:total) || 0) do |pager|
       pager.replace(group.try(:results) || [])
    end
  end

  def read_page
    @page = (params[:page] || 1).to_i
  end

  def schools
    a = User.all.map { |user| user.affiliation }.uniq
  end

  def result_groups query
    groups = search_query(@query).group(:klass).groups
    return {
      casebooks: groups.find {|r| r.value == 'Content::Casebook'},
      cases: groups.find {|r| r.value == 'Case'},
      users: groups.find {|r| r.value == 'User'}
    }
  end

  def search_query query
    page = @page
    Sunspot.search Case, Content::Casebook, User do
      keywords query, fields: [:title, :subtitle, :owner_attributions]

      any_of do
        with :public, true
        if current_user.present?
          with :owner_ids, current_user.id 
        end
      end

      with :owner_ids, params[:author] if params[:author].present?
      with :owner_affiliation, params[:school] if params[:school].present?

      order_by (params[:sort] || 'display_name').to_sym
      group :klass do
        limit PER_PAGE
      end

      adjust_solr_params do |params|
        params['group.offset'] = (page - 1) * PER_PAGE
      end
    end
  end
end
