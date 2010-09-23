class ItemBaseController < BaseController

  before_filter :set_model
  before_filter :require_user, :except => [:index, :show]
  before_filter :load_playlist

  access_control do
    allow all, :to => [:show, :index]
    allow logged_in, :to => [:new, :create]
    allow :admin, :playlist_admin
    allow :owner, :of => :playlist
    allow :editor, :of => :playlist, :to => [:edit, :update]
  end

  def index
    @objects = @model_class.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item_defaults }
    end
  end

  def show
    @object = @model_class.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item_default }
    end
  end

  def new
    @object = @model_class.new

    respond_to do |format|
      format.html { render :partial => "shared/forms/#{@model_class.name.tableize.singularize}" }
      format.js { render :partial => "shared/forms/#{@model_class.name.tableize.singularize}" }
      format.xml  { render :xml => @item_default }
    end
  end

  # GET /item_defaults/1/edit
  def edit
    @object = @model_class.find(params[:id])
  end

  def create
    @object = @model_class.new(params[@param_symbol])

    respond_to do |format|
      if @object.save
        @object.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist => @playlist)
        playlist_item.resource_item = @object

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'ItemDefault was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@object) }
        format.xml  { render :xml => @object, :status => :created, :location => @object }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @object.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    @object = @model_class.find(params[:id])

    respond_to do |format|
      if @object.update_attributes(params[@param_symbol])
        flash[:notice] = "#{@model_class.name.titleize} was successfully updated."
        format.html { render :text => nil }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @object.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @object = @model_class.find(params[:id])
    @object.destroy

    respond_to do |format|
      format.html { redirect_to(item_cases_url) }
      format.xml  { head :ok }
    end
  end

  private
  
  def set_model
    @model_class = controller_class_name.gsub(/Controller/,'').singularize.constantize
    @param_symbol = @model_class.name.tableize.singularize.to_sym
  end

  def load_playlist
    @playlist = Playlist.find(params[:container_id])
  end

end
