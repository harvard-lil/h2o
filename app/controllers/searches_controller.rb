class SearchesController < ApplicationController
  layout 'main'

  def show
    @query = params[:q]
    @type = params[:type] || 'casebooks'
    @results = if @query
      result_groups @query
    else
      result_groups '*'
    end
    @main_group = @results[@type.to_sym]
    if params[:partial]
      render partial: 'results', layout: false, locals: {results: @main_group.results}
    end
  end

  def index
    @results = result_groups '*'
    @main_group = @results[:casebooks]
    render 'searches/show'
  end

  private

  def result_groups query
    groups = search_query(@query).group(:klass).groups
    return {
      casebooks: groups.find {|r| r.value == 'Content::Casebook'},
      cases: groups.find {|r| r.value == 'Case'},
      users: groups.find {|r| r.value == 'User'}
    }
  end

  def search_query query
    Sunspot.search Case, Content::Casebook, User do
      keywords query

      any_of do
        with :public, true
        if current_user.present?
          with :user_id, current_user.id
        end
      end

      order_by (params[:sort] || 'display_name').to_sym
      group :klass do
        limit -1
      end
    end
  end

end
