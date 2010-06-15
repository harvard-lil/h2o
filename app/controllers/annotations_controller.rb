class AnnotationsController < BaseController

  cache_sweeper :annotation_sweeper

  before_filter :load_annotation, :only => [:show, :edit, :update, :destroy]

  def autocomplete_layers
    render :json => Annotation.autocomplete_for(:layers,params[:tag])
  end

  # GET /annotations
  # GET /annotations.xml
  def index
    @annotations = Annotation.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @annotations }
    end
  end

  # GET /annotations/1
  # GET /annotations/1.xml
  def show
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
    @annotation = Annotation.new(params[:annotation])
    @annotation.accepts_role!(:owner, current_user)
    @annotation.user = current_user

    respond_to do |format|
      if @annotation.save
        #force loading
        @layer_count = @annotation.layers.count
        flash[:notice] = 'Annotation was successfully created.'
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
    respond_to do |format|
      if @annotation.update_attributes(params[:annotation])
        flash[:notice] = 'Annotation was successfully updated.'
        format.html { redirect_to(@annotation) }
        format.xml  { head :ok }
      else
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
  rescue
    render :text => 'There seems to have been a problem deleting that item.', :status => :unprocessable_entity
  end

  private

  def load_annotation
    @annotation = Annotation.find((params[:id].blank?) ? params[:annotation_id] : params[:id])
  end

end
