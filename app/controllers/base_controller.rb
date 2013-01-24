class BaseController < ApplicationController
  before_filter :store_location, :only => [:search, :index]

  def playlist_admin_preload
    if current_user
      @is_playlist_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','playlist_admin','superadmin']}).length > 0
    end
  end

  def embedded_pager(model = Case)
    params[:page] ||= 1

    if params[:keywords]
      obj = Sunspot.new_search(model)
      obj.build do
        keywords params[:keywords]
        paginate :page => params[:page], :per_page => 25 || nil
        order_by :score, :desc
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
    @highlighted_playlists = []
    map = { "945" => "Copyright", "671" => "Criminal Law", "911" => "Music and Digital Media", "986" => "Torts" }
    [945, 671, 911, 986].each do |p|
      begin
        playlist = Playlist.find(p)
        @highlighted_playlists << { :title => map[p.to_s], :playlist => playlist } if playlist 
      rescue Exception => e
        Rails.logger.warn "Base#index Exception: #{e.inspect}"
      end
    end
  end

  def search
    set_sort_params
    set_sort_lists
    @results = {}
    @types = [:playlists, :collages, :cases, :medias, :text_blocks]

    @types.each do |type|
      if (request.xhr? && params[:ajax_region] == type.to_s) || !request.xhr?
        @results[type] = Sunspot.new_search(type.to_s.classify.constantize)
        @results[type].build do
          if params.has_key?(:keywords)
            keywords params[:keywords]
          end
          with :public, true
          with :active, true
          paginate :page => params[:page], :per_page => cookies[:per_page] || nil
  
          order_by params[:sort].to_sym, params[:order].to_sym
        end
        @results[type].execute!

        @collection = @results[type] if request.xhr?
      end
    end

    if current_user
      @is_case_admin = current_user.is_case_admin
      @is_text_block_admin = current_user.is_text_block_admin
      @is_media_admin = current_user.is_media_admin
      @is_collage_admin = current_user.is_collage_admin

      @my_collages = current_user.collages
      @my_playlists = current_user.playlists
      @my_cases = current_user.cases
      @my_case_requests = current_user.case_requests
      @my_text_blocks = current_user.text_blocks
      @my_medias = current_user.medias
    else
      @is_collage_admin = @is_case_admin = false
      @my_collages = @my_playlists = @my_cases = @my_text_blocks = @my_medias = []
    end

    playlist_admin_preload

    respond_to do |format|
      format.html do
        if request.xhr?
          @view = params[:ajax_region] == 'cases' ? 'case_obj' : params[:ajax_region].singularize  
          render :partial => 'shared/generic_block'
        else
          render 'search'
        end
      end
    end
  end
end
