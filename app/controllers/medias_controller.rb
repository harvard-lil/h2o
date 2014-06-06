class MediasController < BaseController
  cache_sweeper :media_sweeper
  protect_from_forgery :except => [:destroy]

  def access_level 
    render :json => {
      :logged_in => current_user ? current_user.to_json(:only => [:id, :login]) : false,
      :can_edit => current_user ? Media.where(id: params[:id]).first.can_edit? : false }
  end

  def index
    common_index Media
  end

  def embedded_pager
    super Media
  end

  def new
  end

  def create
    unless params[:media][:tag_list].blank?
      params[:media][:tag_list] = params[:media][:tag_list].downcase
    end
    @media = Media.new(medias_params)
    @media.user = current_user
    verify_captcha(@media)

    if @media.save
      flash[:notice] = "#{@media.media_type.label} was successfully created."
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

    if @media.update_attributes(medias_params)
      flash[:notice] = "#{@media.media_type.label} was successfully updated."
      redirect_to "/medias/#{@media.id}"
    else
      render :action => "edit"
    end
  end

  def show
    set_belongings(Media)
    @type_label = @media.media_type.label
  end

  def destroy
    @media.destroy
    render :json => {}
  end
 
  private
  def medias_params
    params.require(:media).permit(:id, :name, :type, :public, :description, :media_type_id, :content, :tag_list)
  end
end
