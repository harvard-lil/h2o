class BaseController < ApplicationController
  before_action :load_single_resource, :check_authorization_h2o
  caches_page :index, :if => Proc.new { |c| c.instance_variable_get('@page_cache') }

  layout :layout_switch

  def landing
    if current_user
      @user = current_user
      render 'content/dashboard', layout: 'main'
    else
      render 'base/index', layout: 'main'
    end
  end

  def check_authorization_h2o
    return true if params[:controller] == "rails_admin/main"

    if @single_resource.present?
      authorize! action_check, @single_resource
    else
      authorize! action_check, params[:controller].to_sym
    end

    return true
  end

  def load_single_resource
    return if ['user_sessions', 'password_resets', 'login_notifiers', 'base', 'pages', 'rails_admin/main'].include?(params[:controller])

    return if params[:controller] == 'users' && !['edit', 'update'].include?(params[:action])

    if params[:action] == "new"
      model = params[:controller].singularize.classify.constantize
      @single_resource = item = model.new
      instance_variable_set "@#{model.to_s.tableize.singularize}", item
      @page_title = "New #{model.to_s}"
    elsif params[:id].present?
      model = params[:controller].singularize.classify.constantize
      if params[:action] == "new"
        item = model.new
      elsif ["access_level", "save_readable_state"].include?(params[:action])
        item = model.unscoped.where(id: params[:id].to_i).includes(:user).first
      elsif model.respond_to?(:get_single_resource)
        item = model.get_single_resource(params[:id])
      else
        item = model.where(id: params[:id]).first
      end
      if item.present? && item.is_a?(User)
        @single_resource = item
      elsif item.present? && ((item.respond_to?(:user) && item.user.present?))
        @single_resource = item
        instance_variable_set "@#{model.to_s.tableize.singularize}", item
        @page_title = item.name if item.respond_to?(:name)
      else
        render :file => "#{Rails.root}/public/404.html", :status => 404, :layout => false
      end
    end
  end

  def embedded_pager(model = nil, view = 'shared/playlistable_item')
    if model.present?
      params[:filter_type] = model.to_s.tableize
    end

    set_sort_params
    set_sort_lists
    @list_key = model.present? ? model.to_s.tableize.to_sym : :all

    params[:page] ||= 1

    obj = model.nil? ? Sunspot.new_search(Case, TextBlock, Default) : Sunspot.new_search(model)

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
    @page_title = "All Resources | H2O Classroom Tools"

    params[:keywords] = CGI::escapeHTML(params[:keywords].to_s)
    if params.has_key?(:keywords) && params[:keywords].present? && params[:keywords].length > 50
      params[:keywords] = params[:keywords][0..49]
    end

    set_sort_params
    set_sort_lists
    @collection = build_search([TextBlock, Case, Default], params)

    if request.xhr?
      render :partial => 'shared/generic_block'
    else
      render 'shared/list_index'
    end
  end

  def error
    redirect_to root_url, :status => 301
  end

  def not_found
    render :file => "#{Rails.root}/public/404.html", :status => 404, :layout => false
  end

  # Layout is always false for ajax calls
  def layout_switch
    return false if request.xhr?
  end
end
