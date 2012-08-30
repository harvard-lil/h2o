class MediasController < BaseController
  cache_sweeper :media_sweeper
  #caches_page :show

  before_filter :require_user, :except => [:index, :show, :access_level, :embedded_pager]
  before_filter :load_media, :only => [:show, :edit, :update]
  before_filter :store_location, :only => [:index, :show]

  protect_from_forgery :except => []

  access_control do
    allow all, :to => [:index, :show, :addess_level, :embedded_pager, :new, :create]
    allow :owner, :of => :collage, :to => [:destroy, :edit, :update]
    allow :admin, :collage_admin, :superadmin
  end

  def access_level 
    session[:return_to] = "/medias/#{params[:id]}"
    respond_to do |format|
      format.json { render :json => {
        :logged_in => current_user ? current_user.to_json(:only => [:id, :login]) : false,
        :can_edit => current_user ? Media.find(params[:id]).can_edit? : false }
      }
    end
  end

  def build_search(params)
    medias = Sunspot.new_search(Media)
    
    medias.build do
      if params.has_key?(:keywords)
        keywords params[:keywords]
      end
      if params.has_key?(:tag)
        with :tag_list, CGI.unescape(params[:tag])
      end
      with :public, true
      with :active, true
      paginate :page => params[:page], :per_page => 25
      order_by params[:sort].to_sym, params[:order].to_sym
    end
    medias.execute!
    medias
  end

  def index
    params[:page] ||= 1

    if params[:keywords]
      medias = build_search(params)
      t = medias.hits.inject([]) { |arr, h| arr.push(h.result); arr }
      @medias = WillPaginate::Collection.create(params[:page], 25, medias.total) { |pager| pager.replace(t) }
    else
      @medias = Rails.cache.fetch("medias-search-#{params[:page]}-#{params[:tag]}-#{params[:sort]}-#{params[:order]}") do 
        medias = build_search(params)
        t = medias.hits.inject([]) { |arr, h| arr.push(h.result); arr }
        { :results => t, 
          :count => medias.total }
      end
      @medias = WillPaginate::Collection.create(params[:page], 25, @medias[:count]) { |pager| pager.replace(@medias[:results]) }
    end

    if current_user
      @is_media_admin = current_user.is_media_admin
      @my_medias = current_user.medias
      @my_bookmarks = [] # TODO current_user.bookmarks_type(Media, ItemMedia)
    else
      @is_media_admin = false
      @my_medias = @my_bookmarks = []
    end

    respond_to do |format|
      #The following is called via normal page load
      # and via AJAX.
      format.html do
        if request.xhr?
          @view = "media"
          @collection = @medias
          render :partial => 'shared/generic_block'
        else
          render 'index'
        end
      end
      format.xml  { render :xml => @medias }
    end
  end

  def embedded_pager
    super Media
  end

  def new
    @media = Media.new
  end

  def create
    unless params[:media][:tag_list].blank?
      params[:media][:tag_list] = params[:media][:tag_list].downcase
    end
    @media = Media.new(params[:media])

    if @media.save
      @media.accepts_role!(:owner, current_user)
      @media.accepts_role!(:creator, current_user)
      flash[:notice] = 'media was successfully created.'
      redirect_to "/medias/#{@media.id}"
    else
      render :action => "new"
    end
  end

  def edit
  end

  def update
    unless params[:media][:tag_list].blank?
      params[:media][:tag_list] = params[:media][:tag_list].downcase
    end

    if @media.update_attributes(params[:media])
      flash[:notice] = 'Media item was successfully updated.'
      redirect_to "/medias/#{@media.id}"
    else
      render :action => "edit"
    end
  end

  def show
    add_stylesheets 'medias'

    if current_user
      @my_medias = current_user.medias
    end
  end

  private 

  def load_media
    @media = Media.find((params[:id].blank?) ? params[:media_id] : params[:id], :include => [:accepted_roles => {:users => true}])
  end
end
