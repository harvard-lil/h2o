class AnnotationsController < BaseController

  cache_sweeper :annotation_sweeper

  before_filter :require_user, :except => [:show, :annotation_preview]
  before_filter :load_annotation, :only => [:show, :edit, :update, :destroy, :metadata]
  before_filter :preload_collage, :only => [:new, :create]

  access_control do
    allow :superadmin
    allow :admin
    allow :collages_admin
    allow :owner, :of => :collage, :to => [:destroy, :edit, :update, :create, :new, :autocomplete_layers]
    allow all, :to => [:show, :metadata, :annotation_preview]
  end

  def annotation_preview
    render :text => Annotation.format_content(params[:preview]), :layout => false
  end

  def metadata
    @annotation[:object_type] = @annotation.class.to_s
    @annotation[:child_object_name] = 'annotation'
    @annotation[:child_object_plural] = 'annotations'
    @annotation[:child_object_count] = nil
    @annotation[:child_object_type] = 'Annotation'
    @annotation[:child_object_ids] = nil
    @annotation[:title] = @annotation.display_name
    render :xml => @annotation.to_xml(:skip_types => true)
  end

  def autocomplete_layers
    render :json => Annotation.autocomplete_for(:layers,params[:tag])
  end

  # GET /annotations/1
  # GET /annotations/1.xml
  def show
    @editors = @annotation.editors
    @original_creators = @annotation.accepted_roles.find(:all, :conditions => {:name => "original_creator"})
  end

  # GET /annotations/new
  # GET /annotations/new.xml
  def new
    @annotation = Annotation.new
    [:annotation_start, :annotation_end].each do |p|
      @annotation[p] = params[p]
    end
    [:collage_id].each do |p|
      @annotation[p] = (params[p] == 'null') ? nil : params[p]
    end
  end

  # GET /annotations/1/edit
  def edit
  end

  # POST /annotations
  # POST /annotations.xml
  def create
    unless params[:annotation][:layer_list].blank?
      params[:annotation][:layer_list] = params[:annotation][:layer_list].downcase
    end
    @annotation = Annotation.new(params[:annotation])

    respond_to do |format|
      if @annotation.save
        @annotation.accepts_role!(:owner, current_user)
        @annotation.accepts_role!(:editor, current_user)
        @annotation.accepts_role!(:creator, current_user)
        #force loading
        @layer_count = @annotation.layers.count
        #flash[:notice] = 'Annotation was successfully created.'
        format.json { render :json =>  @annotation.to_json(:include => [:layers]) }
        format.html { redirect_to(@annotation) }
        format.xml  { render :xml => @annotation, :status => :created, :location => @annotation }
      else
        format.json { render :text => "We couldn't add that annotation. Sorry!<br/>#{@annotation.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity }
        format.html { render :action => "new" }
        format.xml  { render :xml => @annotation.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /annotations/1
  # PUT /annotations/1.xml
  def update
    unless params[:annotation][:layer_list].blank?
      params[:annotation][:layer_list] = params[:annotation][:layer_list].downcase
    end
    respond_to do |format|
      @annotation.attributes = params[:annotation]
      #Track this editor.
      if @annotation.save
        @annotation.accepts_role!(:editor,current_user)
        #flash[:notice] = 'Annotation was successfully updated.'
        format.json { render :json =>  @annotation.to_json(:include => [:layers]) }
        format.html { redirect_to(@annotation) }
        format.xml  { head :ok }
      else
        format.json { render :text => "We couldn't update that annotation. Sorry!<br/>#{@annotation.errors.full_messages.join('<br/>')}", :status => :unprocessable_entity }
        format.html { render :action => "edit" }
        format.xml  { render :xml => @annotation.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /annotations/1
  # DELETE /annotations/1.xml
  def destroy
    @annotation.destroy
    render :text => "We've deleted that item."
  rescue Exception => e
    logger.warn("Could not delete annotation: #{e.inspect}")
    render :text => "There seems to have been a problem deleting that item. #{e.inspect}", :status => :unprocessable_entity
  end

  private

  def load_annotation
    @annotation = Annotation.find((params[:id].blank?) ? params[:annotation_id] : params[:id], :include => [:layers])
    @collage = @annotation.collage
  end

  def preload_collage
    @collage = Collage.find(params[:collage_id] || params[:annotation][:collage_id])
  end

end
