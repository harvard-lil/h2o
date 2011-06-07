class CollagesController < BaseController

  cache_sweeper :collage_sweeper

  before_filter :is_collage_admin, :except => [:embedded_pager, :metadata]
  before_filter :require_user, :except => [:layers, :annotations, :index, :show, :metadata, :description_preview, :embedded_pager]
  before_filter :prep_resources
  before_filter :load_collage, :only => [:layers, :show, :edit, :update, :destroy, :undo_annotation, :spawn_copy]
  before_filter :list_tags, :only => [:index, :show, :edit]

  caches_action :annotations

  access_control do
    allow all, :to => [:layers, :annotations, :index, :show, :new, :create, :metadata, :description_preview, :spawn_copy, :embedded_pager]    
    allow :owner, :of => :collage, :to => [:destroy, :edit, :update]
    allow :admin, :collage_admin, :superadmin
  end

  def list_tags
    @collage_tags = Tag.find_by_sql("SELECT id, name FROM tags WHERE id IN
		(SELECT tag_id FROM taggings WHERE
			(taggable_type = 'Case' AND taggable_id IN (SELECT annotatable_id FROM collages WHERE annotatable_type = 'Case'))
			OR
			(taggable_type = 'TextBlock' AND taggable_id IN (SELECT annotatable_id FROM collages WHERE annotatable_type = 'TextBlock')
		))")
  end

  def embedded_pager
    super Collage
  end

  def description_preview
    render :text => Collage.format_content(params[:preview]), :layout => false
  end

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
    format.html { render :action => "new" }
    format.xml  { render :xml => e.inspect, :status => :unprocessable_entity }
  end

  def annotations
    @annotations = Annotation.find(:all, 
                                    :conditions => ['collage_id = ?', (params[:id].blank?) ? params[:collage_id] : params[:id]],
                                    :include => :layers,
                                    :order => 'substring(annotation_start from 2)::INTEGER'
                                   )
    respond_to do |format|
      format.json { render :json => @annotations.to_json(:include => [:layers], :except => [:annotation, :annotated_content], :methods => [:formatted_annotation_content]) }
    end
  end

  def index
    @all_playlists = Playlist.all
    @collages = Sunspot.new_search(Collage)
      
    @collages.build do
      unless params[:keywords].blank?
        keywords params[:keywords]
      end
	  unless params[:tag].blank?
	    with :layer_list, params[:tag]
	  end
      with :public, true
      with :active, true
      paginate :page => params[:page], :per_page => cookies[:per_page] || nil
      data_accessor_for(Collage).include = {:annotations => {:layers => []}, :accepted_roles => {}, :annotatable => {}}
      order_by :display_name, :asc
    end

    @collages.execute!

	@my_collages = current_user ? current_user.collages : [] 

    respond_to do |format|
      format.html # index.html.erb
      format.js {render :partial => 'collage_list'}
      format.xml  { render :xml => @collages }
    end
  end

  # GET /collages/1
  # GET /collages/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @collage }
	  format.pdf { render :pdf => "file_name" }
    end
  end

  # GET /collages/new
  # GET /collages/new.xml
  def new
    @collage = Collage.new(:annotatable_type => params[:annotatable_type], :annotatable_id => params[:annotatable_id])

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
        #flash[:notice] = 'Collage was successfully created.'
        format.html { redirect_to(@collage) }
        format.xml  { render :xml => @collage, :status => :created, :location => @collage }
      else
        flash[:notice] = "We couldn't create that collage - " + @collage.errors.full_messages.join(',')
        format.html { render :action => "new" }
        format.xml  { render :xml => @collage.errors, :status => :unprocessable_entity }
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
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @collage.errors, :status => :unprocessable_entity }
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
    end
  end

  private 

  def is_collage_admin
    if current_user
      @is_collage_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','collage_admin','superadmin']}).length > 0
    end
  end

  def prep_resources
    add_javascripts ['collages', 'markitup/jquery.markitup.js','markitup/sets/textile/set.js','markitup/sets/html/set.js']
    add_stylesheets ['/javascripts/markitup/skins/markitup/style.css','/javascripts/markitup/sets/textile/style.css']
  end

  def load_collage
    @collage = Collage.find((params[:id].blank?) ? params[:collage_id] : params[:id], :include => [:accepted_roles => {:users => true}, :annotations => {:layers => true}])
  end

end
