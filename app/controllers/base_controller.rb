class BaseController < ApplicationController
  before_filter :store_location, :only => [:search, :index]

  def playlist_admin_preload
    if current_user
      @playlist_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','playlist_admin','superadmin']}).length > 0
      @playlists_i_can_edit = current_user.playlists_i_can_edit
    end
  end

  def embedded_pager(model = Case)
    params[:page] ||= 1

    if params[:keywords]
      obj = Sunspot.new_search(model)
      obj.build do
        keywords params[:keywords]
        paginate :page => params[:page], :per_page => 25 || nil
        order_by :display_name, :asc
      end
      obj.execute!
      t = obj.hits.inject([]) { |arr, h| arr.push([h.stored(:id), h.stored(:display_name)]); arr }
      @objects = WillPaginate::Collection.create(params[:page], 25, obj.total) { |pager| pager.replace(t) } 
    else
      @objects = Rails.cache.fetch("#{model.to_s.tableize}-embedded-search-#{params[:page]}--display_name-asc") do
        obj = Sunspot.new_search(model)
        obj.build do
          paginate :page => params[:page], :per_page => 25 || nil
          order_by :display_name, :asc
        end
        obj.execute!
        t = obj.hits.inject([]) { |arr, h| arr.push([h.stored(:id), h.stored(:display_name)]); arr }
        { :results => t, :count => obj.total }
      end
      @objects = WillPaginate::Collection.create(params[:page], 25, @objects[:count]) { |pager| pager.replace(@objects[:results]) }
    end

    respond_to do |format|
      format.html { render :partial => 'shared/playlistable_item', :object => model }
    end
  end

  def index
    tcount = Case.find_by_sql("SELECT COUNT(*) AS tcount FROM taggings")
    @counts = {
    :cases => Case.count,
    :text_blocks => TextBlock.count,
    :collages => Collage.count,
    :annotation => Annotation.count,
    :questions => Question.count,
    :rotisseries => RotisserieInstance.count,
    :taggings => tcount[0]['tcount'] 
  }
  end

  def search
    set_sort_lists
    params[:sort] ||= 'display_name'
    params[:order] ||= 'asc'

    if !request.xhr? || params[:ajax_region] == 'playlists'
      @playlists = Sunspot.new_search(Playlist)
      @playlists.build do
        if params.has_key?(:keywords)
          keywords params[:keywords]
        end
        with :public, true
        paginate :page => params[:page], :per_page => cookies[:per_page] || nil
        order_by params[:sort].to_sym, params[:order].to_sym
      end
      @playlists.execute!
    end

    if !request.xhr? || params[:ajax_region] == 'collages'
      @collages = Sunspot.new_search(Collage)
      @collages.build do
        if params.has_key?(:keywords)
          keywords params[:keywords]
        end
        with :public, true
        with :active, true
        paginate :page => params[:page], :per_page => cookies[:per_page] || nil

        order_by params[:sort].to_sym, params[:order].to_sym
      end
      @collages.execute!
    end

    if !request.xhr? || params[:ajax_region] == 'cases'
      @cases = Sunspot.new_search(Case)
      @cases.build do
        if params.has_key?(:keywords)
          keywords params[:keywords]
        end
        with :public, true
        with :active, true
        paginate :page => params[:page], :per_page => cookies[:per_page] || nil
 
        order_by params[:sort].to_sym, params[:order].to_sym
      end
      @cases.execute!
    end

    if current_user
      @is_case_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','case_admin','superadmin']}).length > 0
      @is_collage_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','collage_admin','superadmin']}).length > 0
      @my_collages = current_user.collages
      @my_playlists = current_user.playlists
      @my_cases = current_user.cases
    else
      @is_collage_admin = @is_case_admin = false
      @my_collages = @my_playlists = @my_cases = []
    end

    playlist_admin_preload

    respond_to do |format|
      format.html do
        if request.xhr?
          render :partial => "#{params[:ajax_region]}/#{params[:ajax_region]}_block"
        else
          render 'search'
        end
      end
    end
  end
end
