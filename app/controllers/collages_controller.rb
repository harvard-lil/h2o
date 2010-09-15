class CollagesController < BaseController

  cache_sweeper :collage_sweeper

  before_filter :is_collage_admin
  before_filter :require_user, :except => [:layers, :annotations, :index, :show, :metadata, :description_preview]
  before_filter :prep_resources
  before_filter :load_collage, :only => [:layers, :show, :edit, :update, :destroy, :undo_annotation, :spawn_copy]

  caches_action :annotations

  access_control do
    allow @collage_admin 
    allow :owner, :of => :collage, :to => [:destroy, :edit, :update]
    allow all, :to => [:layers, :annotations, :index, :show, :new, :create, :metadata, :description_preview, :spawn_copy]
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
    @collage = Collage.find((params[:id].blank?) ? params[:collage_id] : params[:id], :include => [:annotations => {:layers => true}])
    respond_to do |format|
      format.json { render :json => @collage.annotations.to_json(:include => [:layers], :except => [:annotation, :annotated_content]) }
    end
  end

  # GET /collages
  # GET /collages.xml
  def index
    @collages = Collage.find(:all, :select => 'id,annotatable_type,annotatable_id,name,description,created_at,updated_at,word_count')

    if current_user
      @my_collages = current_user.collages
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @collages }
    end
  end

  # GET /collages/1
  # GET /collages/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @collage }
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
  end

  # POST /collages
  # POST /collages.xml
  def create
    @collage = Collage.new(params[:collage])
    @collage.accepts_role!(:owner, current_user)
    @collage.accepts_role!(:creator, current_user)
    respond_to do |format|
      if @collage.save
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
      @collage_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','collage_admin','superadmin']}).length > 0
    end
  end

  def prep_resources
    add_javascripts ['jquery.tablesorter.min','collages','markitup/jquery.markitup.pack.js','markitup/sets/textile/set.js']
    add_stylesheets ['tablesorter-h2o-theme/style','cases','markitup/markitup/style.css','markitup/textile/style.css','collages']
  end

  def load_collage
    @collage = Collage.find((params[:id].blank?) ? params[:collage_id] : params[:id], :include => [:accepted_roles => {:users => true}, :annotations => {:layers => true}])
  end

end
