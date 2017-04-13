class BaseController < ApplicationController
  caches_page :index, :if => Proc.new { |c| c.instance_variable_get('@page_cache') }

  def embedded_pager(model = nil, view = 'shared/playlistable_item')
    if model.present?
      params[:filter_type] = model.to_s.tableize
    end

    set_sort_params
    set_sort_lists
    @list_key = model.present? ? model.to_s.tableize.to_sym : :all

    params[:page] ||= 1

    obj = model.nil? ? Sunspot.new_search(Playlist, Collage, Case, TextBlock, Default) : Sunspot.new_search(model)

    obj.build do
      if params[:keywords].present?
        keywords params[:keywords]
      end
      if params.has_key?(:within)
        keywords params[:within]
      end
      if params.has_key?(:klass)
        classes = params[:klass].split(',')
        any_of do
          classes.each { |k| with :klass, k }
        end
      end
      if params.has_key?(:user_ids)
        user_ids = params[:user_ids].split(',')
        any_of do
          user_ids.each { |k| with :user_id, k }
        end
      end

      any_of do
        with :public, true
        with :user_id, current_user.id
      end

      facet(:user_id)
      facet(:klass)
      facet(:primary)
      facet(:secondary)

      paginate :page => params[:page], :per_page => 5 || nil
      order_by params[:sort].to_sym, params[:order].to_sym
    end
    obj.execute!
    build_facet_display(obj)

    formatted_objects = { :results => obj.results, :total => obj.total }

    @display_objects = formatted_objects[:results]
    @objects = formatted_objects[:results].paginate(:page => params[:page], :per_page => 5, :total_entries => formatted_objects[:total])

    render :partial => view
  end

  def index
    @page_cache = true
    @page_title = 'H2O Classroom Tools'
  end

  def search
    @type_lookup = :all
    @page_title = "All Materials | H2O Classroom Tools"

    params[:keywords] = CGI::escapeHTML(params[:keywords].to_s)
    if params.has_key?(:keywords) && params[:keywords].present? && params[:keywords].length > 50
      params[:keywords] = params[:keywords][0..49]
    end

    set_sort_params
    set_sort_lists
    @collection = build_search([Playlist, Collage, TextBlock, Case, Default], params)

    if request.xhr?
      render :partial => 'shared/generic_block'
    else
      render 'shared/list_index'
    end
  end

  def quick_collage
    set_sort_params
    set_sort_lists
    params[:per_page] = 5
    @collection = build_search([TextBlock, Case, Collage], params)

    if params.has_key?(:ajax)
      render :partial => 'shared/generic_block'
    else
      render :partial => 'base/quick_collage'
    end
  end

  def error
    redirect_to root_url, :status => 301
  end

  def not_found
    render :file => "#{Rails.root}/public/404.html", :status => 404, :layout => false
  end
end
