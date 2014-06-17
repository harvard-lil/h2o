class BaseController < ApplicationController
  caches_page :index, :if => Proc.new { |c| c.instance_variable_get('@page_cache') }

  def embedded_pager(model = nil, view = 'shared/playlistable_item')
    if model.present?
      params[:filter_type] = model.to_s.tableize
    end

    set_sort_params
    set_sort_lists
    @list_key = model.present? ? model.to_s.tableize.to_sym : :all
    @list_key = :medias if @list_key == :media

    params[:page] ||= 1

    obj = model.nil? ? Sunspot.new_search(Playlist, Collage, Case, Media, TextBlock, Default) : Sunspot.new_search(model)
   
    obj.build do
      if params[:keywords].present?
        keywords params[:keywords]
      end
      paginate :page => params[:page], :per_page => 5 || nil

      with :public, true
      with :active, true

      order_by params[:sort].to_sym, params[:order].to_sym
    end
    obj.execute!
    formatted_objects = { :results => obj.results, :total => obj.total }

    @display_objects = formatted_objects[:results]
    @objects = formatted_objects[:results].paginate(:page => params[:page], :per_page => 5, :total_entries => formatted_objects[:total])

    render :partial => view
  end

  def partial_results
    per_page = 5
    params[:page] ||= 1

    if params[:type] == "playlists"
      playlists = []
      map = { "945" => "Copyright", "671" => "Criminal Law", "911" => "Music and Digital Media", "986" => "Torts" }
      [945, 671, 911, 986].each do |p|
        begin
          playlist = Playlist.where(id: p).first
          playlists << { :title => map[p.to_s], :playlist => playlist, :user => playlist.user } if playlist 
        rescue Exception => e
          Rails.logger.warn "Base#index Exception: #{e.inspect}"
        end
      end
      @highlighted_playlists = playlists.paginate(:page => params[:page], :per_page => per_page)
    elsif params[:type] == "users"
      @highlighted_users = User.where("karma > 150 AND karma < 250").order("karma DESC").paginate(:page => params[:page], :per_page => per_page)
    elsif params[:type] == "author_playlists"
      playlist = Playlist.where(id: params[:id]).first
      if playlist.present? && playlist.user.present?
        @author_playlists = playlist.user.playlists.paginate(:page => params[:page], :per_page => per_page)
      else
        @author_playlists = [].paginate(:page => params[:page], :per_page => per_page)
      end
    else
      render :partial => "partial_results/empty"
      return
    end
        
    render :partial => "partial_results/#{params[:type]}"
  end

  def tags
    if ["collages", "text_blocks", "playlists", "medias"].include?(params[:klass])
      common_index params[:klass].singularize.camelize.constantize
    else
      redirect_to root_url, :status => 301
    end
  end

  def index
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
        playlist = Playlist.where(id: p).first
        @highlighted[:fall2013] << { :title => playlist.name, :playlist => playlist, :user => playlist.user } if playlist 
      rescue Exception => e
        Rails.logger.warn "Base#index Exception: #{e.inspect}"
      end
    end
    [986, 671, 945, 1943, 911, 633, 66, 626].each do |p|
      begin
        playlist = Playlist.where(id: p).first
        @highlighted[:highlighted] << { :title => playlist.name, :playlist => playlist, :user => playlist.user } if playlist 
      rescue Exception => e
        Rails.logger.warn "Base#index Exception: #{e.inspect}"
      end
    end
    [571, 529, 496, 595, 267, 387, 392, 684, 140].each do |u|
      begin
        user = User.where(id: u).first
        @highlighted[:user] << user
      rescue Exception => e
        Rails.logger.warn "Base#index Exception: #{e.inspect}"
      end
    end
    [3456, 3820, 3230, 3212, 3385].each do |c|
      begin
        collage = Collage.where(id: c).first
        @highlighted[:collage] << collage if collage
      rescue Exception => e
        Rails.logger.warn "Base#index Exception: #{e.inspect}"
      end
    end

    @media_map = {}
    [Default, TextBlock, Case].each do |klass|
      @highlighted[klass.to_s.downcase.to_sym] = klass.where("public IS TRUE AND karma IS NOT NULL").order("karma DESC").limit(5)
    end
    ["Audio", "PDF", "Image", "Video"].each do |media_label|
      mt = MediaType.where(label: media_label).first
      @media_map[mt.slug] = media_label == "Audio" ? "Audio" : "#{media_label}s"
      @highlighted["media_#{mt.slug}".to_sym] = Media.where("public IS TRUE AND media_type_id = #{mt.id}").order("karma DESC").limit(5)
    end
  end

  def search
    params[:keywords] = CGI::escapeHTML(params[:keywords].to_s)
    if params.has_key?(:keywords) && params[:keywords].present? && params[:keywords].length > 50
      params[:keywords] = params[:keywords][0..49]
    end

    [Playlist, Collage, Media, TextBlock, Case, Default].each do |model|
      set_belongings model
    end

    set_sort_params
    set_sort_lists
    @collection = build_search([Playlist, Collage, Media, TextBlock, Case, Default], params)

    if request.xhr?
      render :partial => 'base/search_ajax'
    else
      render 'search'
    end
  end

  def quick_collage
    set_sort_params
    set_sort_lists
    params[:per_page] = 5
    @collection = build_search([TextBlock, Case, Collage], params)

    if params.has_key?(:ajax)
      render :partial => 'base/search_ajax'
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
