class CollagesController < BaseController
  cache_sweeper :collage_sweeper
  caches_page :show

  before_filter :require_user, :except => [:layers, :index, :show, :description_preview, :embedded_pager, :export, :export_unique, :access_level, :collage_lookup]
  before_filter :load_collage, :only => [:layers, :show, :edit, :update, :destroy, :undo_annotation, :spawn_copy, :export, :export_unique, :access_level]
  before_filter :store_location, :only => [:index, :show]

  protect_from_forgery :except => [:spawn_copy, :export_unique]

  access_control do
    allow all, :to => [:layers, :index, :show, :new, :create, :spawn_copy, :description_preview, :embedded_pager, :export, :export_unique, :access_level]

    allow logged_in, :to => [:edit, :update], :if => :allow_edit?

    allow :owner, :of => :collage, :to => [:destroy, :edit, :update, :save_readable_state]
    allow :admin, :collage_admin, :superadmin
  end

  def allow_edit?
    load_collage

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
        :logged_in => current_user.to_json(:only => [:id, :login]),
        :can_edit => can_edit,
        :can_edit_description => can_edit_description,
        :can_edit_annotations => can_edit_annotations,
        :readable_state => @collage.readable_state || { :edit_mode => false }.to_json
      }
    else
      render :json => {
        :logged_in => false,
        :can_edit => false,
        :can_edit_description => false,
        :can_edit_annotations => false
      }
    end
  end

  # TODO: Remove this if unused?
  def layers
    respond_to do |format|
      format.json { render :json => @collage.layers }
    end
  end

  def spawn_copy
    @collage_copy = @collage.fork_it(current_user)
    flash[:notice] = %Q|We've copied "#{@collage_copy.parent}" for you. Please find your copy below.|
    respond_to do |format|
      format.html { redirect_to(@collage_copy) }
      format.xml  { render :xml => @collage_copy, :status => :created, :location => @collage_copy }
    end
  rescue Exception => e
    flash[:notice] = "We couldn't copy that collage - " + e.inspect
    respond_to do |format|
      format.html { render :action => "new" }
      format.xml  { render :xml => e.inspect, :status => :unprocessable_entity }
    end
  end

  def build_search(params)
    collages = Sunspot.new_search(Collage)
    
    collages.build do
      if params.has_key?(:keywords)
        keywords params[:keywords]
      end
      if params.has_key?(:tag)
        with :tag_list, CGI.unescape(params[:tag])
      end
      with :public, true
      with :active, true
      paginate :page => params[:page], :per_page => 25
      order_by params[:sort].to_sym, params[:order].to_sym
    end
    collages.execute!
    collages
  end

  def index
    params[:page] ||= 1

    if params[:keywords]
      collages = build_search(params)
      t = collages.hits.inject([]) { |arr, h| arr.push(h.result); arr }
      @collages = WillPaginate::Collection.create(params[:page], 25, collages.total) { |pager| pager.replace(t) }
    else
      @collages = Rails.cache.fetch("collages-search-#{params[:page]}-#{params[:tag]}-#{params[:sort]}-#{params[:order]}") do 
        collages = build_search(params)
        t = collages.hits.inject([]) { |arr, h| arr.push(h.result); arr }
        { :results => t, 
          :count => collages.total }
      end
      @collages = WillPaginate::Collection.create(params[:page], 25, @collages[:count]) { |pager| pager.replace(@collages[:results]) }
    end

    if current_user
      @is_collage_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','collage_admin','superadmin']}).length > 0
      @my_collages = current_user.collages
      @my_bookmarks = current_user.bookmarks_type(Collage, ItemCollage)
    else
      @is_collage_admin = false
      @my_collages = @my_bookmarks = []
    end

    respond_to do |format|
      #The following is called via normal page load
      # and via AJAX.
      format.html do
        if request.xhr?
          @view = "collage"
          @collection = @collages
          render :partial => 'shared/generic_block'
        else
          render 'index'
        end
      end
      format.xml  { render :xml => @collages }
    end
  end

  # GET /collages/1
  # GET /collages/1.xml
  def show
    add_javascripts ['collages', 'jquery.hoverIntent.minified', 'markitup/jquery.markitup.js','markitup/sets/textile/set.js','markitup/sets/html/set.js', 'jquery.tipsy']
    add_stylesheets ['/javascripts/markitup/skins/markitup/style.css','/javascripts/markitup/sets/textile/style.css', 'collages']

    @color_map = {}
    @collage.layers.each do |layer|
      map = @collage.color_mappings.detect { |cm| cm.tag_id == layer.id }
      @color_map[layer.name] = map.hex if map
    end

    respond_to do |format|
      format.html { render 'show' }
      format.xml  { render :xml => @collage }
    end
  end

  # GET /collages/new
  # GET /collages/new.xml
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
      @collage.tag_list = annotatable.tags.select { |t| t.name }.join(', ')
    end

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @collage }
    end
  end

  # GET /collages/1/edit
  def edit
    if @collage.metadatum.blank?
      @collage.build_metadatum
    end
  end

  # POST /collages
  # POST /collages.xml
  def create
    @collage = Collage.new(params[:collage])
    respond_to do |format|
      if @collage.save
        @collage.accepts_role!(:owner, current_user)
        @collage.accepts_role!(:creator, current_user)
        session[:just_born] = true

        format.html { redirect_to(@collage) }
        format.xml  { render :xml => @collage, :status => :created, :location => @collage }
        format.json { render :json => { :type => 'collages', :id => @collage.id, :error => false } }
      else
        flash[:notice] = "We couldn't create that collage - " + @collage.errors.full_messages.join(',')

        format.html { render :action => "new" }
        format.xml  { render :xml => @collage.errors, :status => :unprocessable_entity }
        format.json { render :json => { :error => true, :message => "We could not collage this item: #{@collage.errors.full_messages.join('<br />')}" } }
      end
    end
  end

  # PUT /collages/1
  # PUT /collages/1.xml
  def update
    respond_to do |format|
      @collage.attributes = params[:collage]
      #Track this editor.
      @collage.accepts_role!(:editor,current_user)
      if @collage.save
        flash[:notice] = 'Collage was successfully updated.'
        format.html { redirect_to(@collage) }
        format.xml  { head :ok }
        format.json { render :json => { :type => 'collages', :id => @collage.id } }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @collage.errors, :status => :unprocessable_entity }
        format.json { render :json => { :type => 'collages', :id => @collage.id } }
      end
    end
  end

  # DELETE /collages/1
  # DELETE /collages/1.xml
  def destroy
    @collage.destroy

    respond_to do |format|
      format.html { redirect_to(collages_url) }
      format.xml  { head :ok }
      format.json { render :json => {} }
    end
  end

  def save_readable_state
    #TODO: Figure out why this is making so many DB calls for optimization
    Collage.update(params[:id], :readable_state => params[:readable_state], :words_shown => params[:words_shown])
    respond_to do |format|
      format.json { render :json => { :time => Time.now.to_s(:simpledatetime) } }
    end
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

  private 

  def load_collage
    @collage = Collage.find((params[:id].blank?) ? params[:collage_id] : params[:id], :include => [:accepted_roles => {:users => true}])
  end
end
