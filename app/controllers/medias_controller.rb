class MediasController < BaseController
  cache_sweeper :media_sweeper
  #caches_page :show

  before_filter :require_user, :except => [:index, :show, :access_level, :embedded_pager]
  before_filter :load_single_resource, :only => [:show, :edit, :update, :destroy]
  before_filter :store_location, :only => [:index, :show]
  before_filter :create_brain_buster, :only => [:new]
  before_filter :validate_brain_buster, :only => [:create]
  before_filter :restrict_if_private, :only => [:show, :edit, :update]
  protect_from_forgery :except => []

  access_control do
    allow all, :to => [:index, :show, :addess_level, :embedded_pager, :new, :create]
    allow :owner, :of => :collage, :to => [:destroy, :edit, :update]
    allow :admin, :collage_admin, :superadmin
  end

  def access_level 
    session[:return_to] = "/medias/#{params[:id]}"
    render :json => {
      :logged_in => current_user ? current_user.to_json(:only => [:id, :login]) : false,
      :can_edit => current_user ? Media.find(params[:id]).can_edit? : false }
  end

  def index
    common_index Media
  end

  def embedded_pager
    super Media
  end

  def new
    add_javascripts ['visibility_selector']
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
    add_javascripts ['visibility_selector']
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
    set_belongings(Media)
  end

  # DELETE /medias/1
  def destroy
    @media.destroy
    render :json => {}
  end
 
  def render_or_redirect_for_captcha_failure
    @media = Media.new(params[:media])
    @media.valid?
    create_brain_buster
    render :action => "new"
  end
end
