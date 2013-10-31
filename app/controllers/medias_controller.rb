class MediasController < BaseController
  cache_sweeper :media_sweeper

  before_filter :require_user, :except => [:index, :show, :access_level, :embedded_pager]
  before_filter :load_single_resource, :only => [:show, :edit, :update, :destroy]
  before_filter :create_brain_buster, :only => [:new]
  before_filter :validate_brain_buster, :only => [:create]
  before_filter :restrict_if_private, :only => [:show, :edit, :update]
  protect_from_forgery :except => []

  access_control do
    allow all, :to => [:index, :show, :addess_level, :embedded_pager, :new, :create]
    
    allow logged_in, :to => [:destroy, :edit, :update], :if => :is_owner?
    
    allow :superadmin
  end

  def access_level 
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
    @media.user = current_user

    if @media.save
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
    @type_label = @media.media_type.label
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
