class BaseController < ApplicationController
  caches_page :index, :if => Proc.new { |c| c.instance_variable_get('@page_cache') }

  def embedded_pager(model = nil)
    set_sort_params
    set_sort_lists
    @list_key = model.present? ? model.to_s.tableize.to_sym : :all
    params[:page] ||= 1

    if params[:keywords].present?
      @objects = model.nil? ? Sunspot.new_search(Playlist, Collage, Case, Media, TextBlock, Default) : Sunspot.new_search(model)
      @objects.build do
        keywords params[:keywords]
        paginate :page => params[:page], :per_page => 5 || nil

        with :public, true
        with :active, true

        order_by params[:sort].to_sym, params[:order].to_sym
      end
      @objects.execute!
    else
      cache_key = model.present? ? "#{model.to_s.tableize}-embedded-search-#{params[:page]}--karma-asc" :
        "embedded-search-#{params[:page]}--karma-asc"
      @objects = Rails.cache.fetch(cache_key) do
        obj = model.nil? ? Sunspot.new_search(Playlist, Collage, Case, Media, TextBlock, Default) : Sunspot.new_search(model)
        obj.build do
          paginate :page => params[:page], :per_page => 5 || nil

          with :public, true
          with :active, true

          order_by params[:sort].to_sym, params[:order].to_sym
        end
        obj.execute!
        obj
      end
    end

    render :partial => 'shared/playlistable_item'
  end

  def partial_results
    per_page = 5
    params[:page] ||= 1

    if params[:type] == "playlists"
      playlists = []
      map = { "945" => "Copyright", "671" => "Criminal Law", "911" => "Music and Digital Media", "986" => "Torts" }
      [945, 671, 911, 986].each do |p|
        begin
          playlist = Playlist.find(p)
          playlists << { :title => map[p.to_s], :playlist => playlist, :user => playlist.user } if playlist 
        rescue Exception => e
          Rails.logger.warn "Base#index Exception: #{e.inspect}"
        end
      end
      @highlighted_playlists = playlists.paginate(:page => params[:page], :per_page => per_page)
    elsif params[:type] == "users"
      @highlighted_users = User.find(:all, :conditions => "karma > 150 AND karma < 250", :order => "karma DESC").paginate(:page => params[:page], :per_page => per_page)
    elsif params[:type] == "author_playlists"
      @author_playlists = Playlist.find(params[:id]).user.playlists.paginate(:page => params[:page], :per_page => per_page)
    end
        
    render :partial => "partial_results/#{params[:type]}"
  end

  def index
    add_javascripts 'masonry.min'

    @page_cache = true
    @page_title = 'H2O Classroom Tools'

    per_page = 8

    @highlighted = { :fall2013 => [], 
                     :highlighted => [], 
                     :user => [], 
                     :collage => [], 
                     :media_image => [], 
                     :media_pdf => [], 
                     :media_audio => [], 
                     :media_video => [], 
                     :textblock => [], 
                     :case => [],
                     :default => []
                   }
    [1374, 1995, 1324, 1162, 711, 1923, 1889, 1844, 1510].each do |p|
      begin
        playlist = Playlist.find(p)
        @highlighted[:fall2013] << { :title => playlist.name, :playlist => playlist, :user => playlist.user } if playlist 
      rescue Exception => e
        Rails.logger.warn "Base#index Exception: #{e.inspect}"
      end
    end
    [986, 671, 945, 1943, 911, 633, 66, 626].each do |p|
      begin
        playlist = Playlist.find(p)
        @highlighted[:highlighted] << { :title => playlist.name, :playlist => playlist, :user => playlist.user } if playlist 
      rescue Exception => e
        Rails.logger.warn "Base#index Exception: #{e.inspect}"
      end
    end
    [571, 529, 496, 595, 267, 387, 392, 684, 140].each do |u|
      begin
        user = User.find(u)
        @highlighted[:user] << user
      rescue Exception => e
        Rails.logger.warn "Base#index Exception: #{e.inspect}"
      end
    end

    [Collage, Default, TextBlock, Case].each do |klass|
      klass.find(:all, :conditions => "public IS TRUE AND karma IS NOT NULL", :order => "karma DESC", :limit => 5).each do |item|
        @highlighted[klass.to_s.downcase.to_sym] << item
      end
    end
    @media_map = {}
    ["Audio", "PDF", "Image", "Video"].each do |media_label|
      mt = MediaType.find_by_label(media_label)
      @media_map[mt.slug] = media_label == "Audio" ? "Audio" : "#{media_label}s"
      Media.find(:all, :conditions => "public IS TRUE AND media_type_id = #{mt.id}", :order => "karma DESC", :limit => 5).each do |item|
        @highlighted["media_#{mt.slug}".to_sym] << item
      end
    end
  end

  def common_search(models)
    set_sort_params
    set_sort_lists
    params[:page] ||= 1
    params[:per_page] ||= 20

    @results = Sunspot.new_search(models)
    @results.build do
      if params.has_key?(:keywords)
        keywords params[:keywords]
      end
      keywords params[:keywords]
      with :public, true
      with :active, true
      order_by :score, :desc
      paginate :page => params[:page], :per_page => params[:per_page]

      order_by params[:sort].to_sym, params[:order].to_sym
    end
    @results.execute!
    models.each do |model|
      set_belongings model
    end
  end

  def search
    params[:keywords] = CGI::escapeHTML(params[:keywords])
    if params.has_key?(:keywords) && params[:keywords].present? && params[:keywords].length > 50
      params[:keywords] = params[:keywords][0..49]
    end

    common_search [Playlist, Collage, Media, TextBlock, Case, Default]

    if request.xhr?
      render :partial => 'base/search_ajax' 
    else
      render 'search'
    end
  end

  def quick_collage
    params[:per_page] = 5
    common_search [TextBlock, Case, Collage]

    if params.has_key?(:ajax)
      render :partial => 'base/search_ajax' 
    else
      render :partial => 'base/quick_collage'
    end
  end

  def error
    redirect_to root_url, :status => 301
  end

  def load_single_resource
    if params[:id].present?
      model = params[:controller] == "medias" ? Media : params[:controller].singularize.classify.constantize
      item = (model == Playlist && params[:action] == "show") ? model.find(params[:id], :include => :playlist_items) : model.find(params[:id])
      if item.present?
        @single_resource = item
        instance_variable_set "@#{model.to_s.tableize.singularize}", item
        @page_title = item.name
      end
    end
  end

  def is_owner?
    load_single_resource

    @single_resource.present? && @single_resource.owner?
  end

end
