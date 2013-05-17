class DefaultsController < BaseController
  cache_sweeper :default_sweeper

  before_filter :load_single_resource, :only => [:edit, :update, :destroy]
  before_filter :require_user, :except => [:index, :embedded_pager, :show]

  access_control do
    allow all, :to => [:index, :show, :embedded_pager, :new, :create]
    allow :owner, :of => :default, :to => [:destroy, :edit, :update]
    allow :admin, :superadmin
  end

  def index
    common_index Default
  end

  def embedded_pager
    super Default
  end

  def new
    @default = Default.new
  end

  def edit
  end

  def create
    @default = Default.new(params[:default])
    if @default.save
      @default.accepts_role!(:owner, current_user)
      @default.accepts_role!(:creator, current_user)
      flash[:notice] = 'Link was successfully created.'
      redirect_to defaults_path
    else
      render :actionn => "new"
    end
  end

  def update
    if @default.update_attributes(params[:default])
      flash[:notice] = 'Link was succeessfully updated.'
      redirect_to defaults_path
    else
      render :actionn => "new"
    end
  end

  def destroy
    @default.destroy
    render :json => {}
  end
end
