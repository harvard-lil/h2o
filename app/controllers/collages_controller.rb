class CollagesController < BaseController
  cache_sweeper :collage_sweeper
  
  before_filter :require_user, :except => [:layers, :index, :show, :description_preview, :embedded_pager, :export, :export_unique, :access_level, :collage_lookup, :heatmap]
  before_filter :load_single_resource, :only => [:layers, :show, :edit, :update, :destroy, :undo_annotation, :copy, :export, :export_unique, :access_level, :heatmap]
  before_filter :store_location, :only => [:index, :show]

  protect_from_forgery :except => [:export_unique]
  before_filter :restrict_if_private, :only => [:layers, :show, :edit, :update, :destroy, :undo_annotation, :copy, :prepare_copy, :export, :export_unique, :access_level, :heatmap]
  caches_page :show, :if => Proc.new{|c| c.instance_variable_get('@collage').public?}

  access_control do
    allow all, :to => [:layers, :index, :show, :new, :create, :description_preview, :embedded_pager, :export, :export_unique, :access_level, :heatmap]

    allow logged_in, :to => [:edit, :update, :copy, :prepare_copy], :if => :allow_edit?

    allow :owner, :of => :collage, :to => [:destroy, :edit, :update, :save_readable_state]
    allow :admin, :collage_admin, :superadmin
  end

  def allow_edit?
    current_user.can_permission_collage("edit_collage", @collage)
  end

  def embedded_pager
    super Collage
  end

  def description_preview
    render :text => Collage.format_content(params[:preview]), :layout => false
  end

  def access_level 
    session[:return_to] = "/collages/#{params[:id]}"

    if current_user
      can_edit = @collage.can_edit?
      can_edit_description = can_edit || current_user.can_permission_collage("edit_collage", @collage)
      can_edit_annotations = can_edit || current_user.can_permission_collage("edit_annotations", @collage)

      render :json => {
        :logged_in            => current_user.to_json(:only => [:id, :login]),
        :can_edit             => can_edit,
        :can_edit_description => can_edit_description,
        :can_edit_annotations => can_edit_annotations,
        :playlists            => current_user.playlists.to_json(:only => [:id, :name]),
        :readable_state       => @collage.readable_state || { :edit_mode => false }.to_json,
        :bookmarks            => current_user.bookmarks_map.to_json,
        :custom_block         => 'collage_afterload'
      }
    else
      render :json => {
        :logged_in            => false,
        :can_edit             => false,
        :can_edit_description => false,
        :can_edit_annotations => false,
        :playlists            => [],
        :readable_state       => @collage.readable_state || { :edit_mode => false }.to_json,
        :custom_block         => 'collage_afterload'
      }
    end
  end

  def heatmap
    render :json => { :heatmap => @collage.heatmap }
  end

  # TODO: Remove this if unused?
  def layers
    render :json => @collage.layers
  end

  def prepare_copy
    @collage = Collage.find(params[:id])
  end

  def copy
    @collage_copy = @collage.fork_it(current_user, params[:collage])

    if @collage_copy.id.nil?
      render :json => { :error => true, :message => "#{@collage_copy.errors.full_messages.join(',')}" }
      return
    end

    render :json => { :type => 'collages', :id => @collage_copy.id }
  rescue Exception => e
    render :json => { :error => true, :message => "Could not process. Please try again." }, :status => :unprocessable_entity
  end

  def index
    common_index Collage
  end

  # GET /collages/1
  def show
    @page_cache = true if @collage.public?
    @editability_path = access_level_collage_path(@collage)
    add_javascripts ['collages', 'markitup/jquery.markitup.js','markitup/sets/textile/set.js','markitup/sets/html/set.js', 'jquery.xcolor']
    add_stylesheets ['/javascripts/markitup/skins/markitup/style.css','/javascripts/markitup/sets/textile/style.css', 'collages']

    @color_map = @collage.color_map
  end

  # GET /collages/new
  def new
    klass = params[:annotatable_type].to_s.classify.constantize

    @collage = Collage.new(:annotatable_type => params[:annotatable_type], :annotatable_id => params[:annotatable_id])
    if klass == Case
      annotatable = klass.find(params[:annotatable_id])
      @collage.name = annotatable.short_name
      @collage.tag_list = annotatable.tags.select { |t| t.name }.join(', ')
    end
    if klass == TextBlock
      annotatable = klass.find(params[:annotatable_id])
      @collage.name = annotatable.name
      @collage.tag_list = annotatable.tags.select { |t| t.name }.join(', ')
    end
  end

  # GET /collages/1/edit
  def edit
    if @collage.metadatum.blank?
      @collage.build_metadatum
    end
  end

  # POST /collages
  def create
    @collage = Collage.new(params[:collage])
    if @collage.save
      @collage.accepts_role!(:owner, current_user)
      @collage.accepts_role!(:creator, current_user)

      render :json => { :type => 'collages', :id => @collage.id, :error => false }
    else
      render :json => { :error => true, :message => "We could not collage this item: #{@collage.errors.full_messages.join('<br />')}" }
    end
  end

  # PUT /collages/1
  def update
    @collage.attributes = params[:collage]
    #Track this editor.
    @collage.accepts_role!(:editor,current_user)

    if @collage.save
      render :json => { :type => 'collages', :id => @collage.id }
    else
      render :json => { :type => 'collages', :id => @collage.id }
    end
  end

  # DELETE /collages/1
  def destroy
    @collage.destroy

    render :json => {}
  end

  def save_readable_state
    #TODO: Figure out why this is making so many DB calls for optimization
    Collage.update(params[:id], :readable_state => params[:readable_state], :words_shown => params[:words_shown])
    render :json => { :time => Time.now.to_s(:simpledatetime) }
  end

  def export
    render :layout => 'print'
  end

  def export_unique
    render :action => 'export', :layout => 'print'
  end

  def collage_lookup
    render :json => { :items => @current_user.collages.collect { |p| { :display => p.name, :id => p.id } } }
  end
end
