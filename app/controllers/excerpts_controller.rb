class ExcerptsController < BaseController

  before_filter :prep_resources

  # GET /excerpts
  # GET /excerpts.xml
  def index
    @excerpts = Excerpt.all
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @excerpts }
    end
  end

  # GET /excerpts/1
  # GET /excerpts/1.xml
  def show
    @excerpt = Excerpt.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @excerpt }
    end
  end

  # GET /excerpts/new
  # GET /excerpts/new.xml
  def new
    @excerpt = Excerpt.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @excerpt }
    end
  end

  # GET /excerpts/1/edit
  def edit
    @excerpt = Excerpt.find(params[:id])
  end

  # POST /excerpts
  # POST /excerpts.xml
  def create
    @excerpt = Excerpt.new(params[:excerpt])
    @excerpt.accepts_role!(:excerpter, current_user)
    @excerpt.user = current_user
    @excerpt.collage_id = 1

    [:anchor_x_path, :focus_x_path].each do |p|
      @excerpt[p] = params[p]
    end
    [:anchor_sibling_offset, :anchor_offset, :focus_sibling_offset,:focus_offset].each do |p|
      @excerpt[p] = (params[p] == 'null') ? nil : params[p]
    end

    respond_to do |format|
      if @excerpt.save
        flash[:notice] = 'Excerpt was successfully created.'
        format.json { render :json => {:message => 'Excerpted!', :excerpt_id => @excerpt.id } }
        format.html { redirect_to(@excerpt) }
        format.xml  { render :xml => @excerpt, :status => :created, :location => @excerpt }
      else
        logger.warn(@excerpt.errors.full_messages.join('<br/>'))
        format.json { render :json => "We couldn't add that excerpt - sorry!" }
        format.html { render :action => "new" }
        format.xml  { render :xml => @excerpt.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /excerpts/1
  # PUT /excerpts/1.xml
  def update
    @excerpt = Excerpt.find(params[:id])

    respond_to do |format|
      if @excerpt.update_attributes(params[:excerpt])
        flash[:notice] = 'Excerpt was successfully updated.'
        format.html { redirect_to(@excerpt) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @excerpt.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /excerpts/1
  # DELETE /excerpts/1.xml
  def destroy
    @excerpt = Excerpt.find(params[:id])
    @excerpt.destroy

    respond_to do |format|
      format.html { redirect_to(excerpts_url) }
      format.xml  { head :ok }
    end
  end

  private 

  def prep_resources
    add_javascripts 'collages'
  end

end
