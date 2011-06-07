class ItemBaseController < BaseController

  before_filter :set_model
  before_filter :load_object_and_playlist, :except => [:new, :create]
  before_filter :create_object_and_load_playlist, :only => [:new, :create]
  before_filter :require_user, :except => [:index, :show]

  access_control do
    allow all, :to => [:show, :index]
#    allow logged_in, :to => [:new, :create]
    allow :admin, :playlist_admin, :superadmin
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
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item_default }
    end
  end

  def new
    @object.url = params[:url_string]    
    
    respond_to do |format|
      format.html { render :partial => "shared/forms/#{@model_class.name.tableize.singularize}" }
      format.js { render :partial => "shared/forms/#{@model_class.name.tableize.singularize}" }
      format.xml  { render :xml => @item_default }
    end
  end

  # GET /item_defaults/1/edit
  def edit
    respond_to do |format|
      format.html { render :partial => "shared/forms/#{@model_class.name.tableize.singularize}" }
      format.js { render :partial => "shared/forms/#{@model_class.name.tableize.singularize}" }
      format.xml  { render :xml => @item_default }
    end
  end

  def create
    @object.update_attributes(params[@param_symbol])

    @base_object = nil
    logger.warn('Base model class' + @base_model_class.inspect)

    if @base_model_class
      begin
        #We believe we have found an object we can link directly to in this instance. Let's see!
        uri = URI.parse(params[@param_symbol][:url])
        recognized_item = ActionController::Routing::Routes.recognize_path(uri.path, :method => :get)
        @base_object = @base_model_class.find(recognized_item[:id])

        logger.warn('URL manually passed in:' + params[@param_symbol][:url])
        logger.warn('URL we guessed:' + url_for(@base_object))

        #FIXME: This might break if an h2o instances is hosted under a directory.
        if params[@param_symbol][:url] == url_for(@base_object)
          #This looks like it's a local object we can link directly to.
          @object.actual_object = @base_object
        else
          # Not local. Do nothing.

        end
        rescue Exception => e
          logger.warn('oopsy.' + e.inspect)
        end
    end

    respond_to do |format|
      if @object.save
        @object.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist => @playlist)
        playlist_item.resource_item = @object

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        #flash[:notice] = 'ItemDefault was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@object) }
        format.xml  { render :xml => @object, :status => :created, :location => @object }
      else
        format.js {
          render :text => "We couldn't add that playlist item. Sorry!<br/>#{@object.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity 
        }
        format.html { render :action => "new" }
        format.xml  { render :xml => @object.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @object.update_attributes(params[@param_symbol])
        flash[:notice] = "#{@model_class.name.titleize} was successfully updated."
        format.js { render :text => nil }
        format.html { render :text => nil }
        format.xml  { head :ok }
      else
        format.js {
          render :text => "We couldn't update that playlist item. Sorry!<br/>#{@object.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity 
        }
        format.html { render :action => "edit" }
        format.xml  { render :xml => @object.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @object = @model_class.find(params[:id])
    @object.destroy

    respond_to do |format|
      format.js { render :text => nil }
      format.html { redirect_to(item_cases_url) }
      format.xml  { head :ok }
    end
  end

  private
  
  def set_model
    @model_class = controller_class_name.gsub(/Controller/,'').singularize.constantize
    @base_model_class = nil

    begin
      @base_model_class = controller_class_name.gsub(/Item|Controller/,'').singularize.constantize
    rescue Exception => e
      logger.warn("We don't have a local type that's equivalent to that object: #{e.inspect}")
    end

    @param_symbol = @model_class.name.tableize.singularize.to_sym
  end

  def load_object_and_playlist
    @object = @model_class.find(params[:id])
    @playlist = @object.playlist_item.playlist
  end

  def create_object_and_load_playlist
    @object = @model_class.new
    @playlist = Playlist.find(params[:container_id])
  end

end
