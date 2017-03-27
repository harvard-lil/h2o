class MediasController < BaseController
  cache_sweeper :media_sweeper
  protect_from_forgery :except => [:destroy]

  before_action :limit_missing_item, :only => :destroy
  
  def index
    common_index Media
  end

  def embedded_pager
    super Media
  end

  def new
  end

  def create
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
    if @media.update_attributes(medias_params)
      flash[:notice] = "#{@media.media_type.label} was successfully updated."
      redirect_to "/medias/#{@media.id}"
    else
      render :action => "edit"
    end
  end

  def show
    http_match = @media.content.scan(/http:\/\//)
    if http_match.size == 1
      if @media.content.match(/^http:/)
        redirect_to @media.content
      else
        url = @media.content.scan(/http:\/\/[^"]*/)
        redirect_to url.first
      end
    end
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
