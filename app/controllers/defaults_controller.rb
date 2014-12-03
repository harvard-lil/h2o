class DefaultsController < BaseController
  cache_sweeper :default_sweeper
  protect_from_forgery :except => [:destroy, :copy]
  before_filter :limit_missing_item, :only => :destroy

  def show
  end

  def copy
    default_copy = @default.h2o_clone(current_user, params[:default])
    verify_captcha(default_copy)

    if default_copy.save
      render :json => { :type => 'defaults', :id => default_copy.id }
    else
      render :json => { :error => true, :message => default_copy.errors.full_messages }
    end
  end

  def index
    common_index Default
  end

  def embedded_pager
    super Default
  end

  def new
    @default = Default.new
    @default.build_metadatum
  end

  def edit
    if @default.metadatum.blank?
      @default.build_metadatum
    end
  end

  def create
    @default = Default.new(defaults_params)
    @default.user = current_user
    verify_captcha(@default)

    if @default.save
      flash[:notice] = 'Link was successfully created.'
      redirect_to edit_default_path(@default)
    else
      render :action => "new"
    end
  end

  def update
    if @default.update_attributes(defaults_params)
      flash[:notice] = 'Link was succeessfully updated.'
      redirect_to default_path(@default.id)
    else
      render :action => "edit"
    end
  end

  def destroy
    @default.destroy
    render :json => {}
  end

  private
  def defaults_params
    params.require(:default).permit(:id, :name, :url, :description, :content_type, :tag_list,
                                       metadatum_attributes: [:contributor, :coverage, :creator, :date,
                                                              :description, :format, :identifier, :language,
                                                              :publisher, :relation, :rights, :source,
                                                              :subject, :title, :dc_type, :classifiable_type, 
                                                              :classifiable_id ])
  end
end
