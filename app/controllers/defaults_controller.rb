class DefaultsController < BaseController
  cache_sweeper :default_sweeper

  before_filter :load_single_resource, :only => [:edit, :update, :destroy, :show, :copy]
  before_filter :require_user, :except => [:index, :embedded_pager, :show]
  before_filter :create_brain_buster, :only => [:new]
  before_filter :validate_brain_buster, :only => [:create]

  access_control do
    allow all, :to => [:index, :show, :embedded_pager, :new, :create]

    allow logged_in, :to => [:copy]

    allow logged_in, :to => [:destroy, :edit, :update], :if => :is_owner?

    allow :superadmin
  end

  def show
  end

  def copy
    default_copy = @default.clone
    default_copy.parent = @default
    default_copy.karma = 0
    default_copy.user = current_user

    if default_copy.save
      render :json => { :type => 'links', :id => default_copy.id }
    else
      render :json => { :type => 'links' }, :status => :unprocessable_entity
    end
  end

  def index
    common_index Default
  end

  def embedded_pager
    super Default
  end

  def new
    add_javascripts ['visibility_selector', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_default']

    @default = Default.new
    @default.build_metadatum
  end

  def render_or_redirect_for_captcha_failure
    add_javascripts ['visibility_selector', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_default']

    @default = Default.new(params[:default])
    @default.build_metadatum
    @default.valid?
    create_brain_buster
    render :action => "new"
  end

  def edit
    add_javascripts ['visibility_selector', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_default']

    if @default.metadatum.blank?
      @default.build_metadatum
    end
  end

  def create
    unless params[:default][:tag_list].blank?
      params[:default][:tag_list] = params[:default][:tag_list].downcase
    end

    @default = Default.new(params[:default])
    @default.user = current_user

    if @default.save
      flash[:notice] = 'Link was successfully created.'
      redirect_to edit_default_path(@default)
    else
      add_javascripts ['visibility_selector', 'h2o_wysiwig', 'switch_editor']
      add_stylesheets ['new_default']

      @default.build_metadatum
      render :action => "new"
    end
  end

  def update
    if @default.update_attributes(params[:default])
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
end
