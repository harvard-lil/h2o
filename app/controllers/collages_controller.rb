class CollagesController < BaseController

  cache_sweeper :collage_sweeper

  before_filter :require_user, :except => [:layers, :annotations, :index, :show, :metadata, :description_preview]
  before_filter :prep_resources
  before_filter :load_collage, :only => [:layers, :annotations, :show, :edit, :update, :destroy, :undo_annotation]  

  access_control do
    allow :admin
    allow :owner, :of => :collage, :to => [:destroy, :edit, :update]
    allow all, :to => [:layers, :annotations, :index, :show, :new, :create, :metadata, :description_preview]
  end

  def description_preview
    render :text => Collage.format_content(params[:preview]), :layout => false
  end

  def layers
    respond_to do |format|
      format.json { render :json => @collage.layers }
    end
  end

  def annotations
    respond_to do |format|
      format.json { render :json => @collage.annotations.to_json(:include => [:layers], :except => [:annotation, :annotated_content]) }
    end
  end

  # GET /collages
  # GET /collages.xml
  def index
    @collages = Collage.find(:all, :include => [:annotations => [:layers], :annotatable => true])
    if current_user
      @my_collages = @collages.find_all{|c| c.accepts_role?(:owner, current_user)}
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
      if @collage.update_attributes(params[:collage])
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

  def prep_resources
    add_javascripts ['jquery.tablesorter.min','collages','markitup/jquery.markitup.pack.js','markitup/sets/textile/set.js']
    add_stylesheets ['tablesorter-h2o-theme/style','cases','markitup/markitup/style.css','markitup/textile/style.css','collages']
  end

  def load_collage
    @collage = Collage.find((params[:id].blank?) ? params[:collage_id] : params[:id], :include => {:annotations => [:layers]})
  end

end
