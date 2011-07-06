require 'tempfile'

class CollagesController < BaseController

  cache_sweeper :collage_sweeper

  before_filter :is_collage_admin, :except => [:embedded_pager]
  before_filter :require_user, :except => [:layers, :index, :show, :description_preview, :embedded_pager, :export, :record_collage_print_state]
  before_filter :load_collage, :only => [:layers, :show, :edit, :update, :destroy, :undo_annotation, :spawn_copy, :save_readable_state, :export, :record_collage_print_state]

  access_control do
    allow all, :to => [:layers, :index, :show, :new, :create, :description_preview, :spawn_copy, :embedded_pager, :export, :record_collage_print_state]    
    allow :owner, :of => :collage, :to => [:destroy, :edit, :update, :save_readable_state]
    allow :admin, :collage_admin, :superadmin
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

  def index
    @collages = Sunspot.new_search(Collage)
    sort_base_url = ''
     
	if !params.has_key?(:sort)
	  params[:sort] = "display_name"
	end

    @collages.build do
      if params.has_key?(:keywords)
        keywords params[:keywords]
		sort_base_url += "&keywords=#{params[:keywords]}"
      end
	  if params.has_key?(:tag)
	    with :tag_list, CGI.unescape(params[:tag])
		sort_base_url += "&tag=#{params[:tag]}"
	  end
      with :public, true
      with :active, true
      paginate :page => params[:page], :per_page => cookies[:per_page] || nil
	  order_by params[:sort].to_sym, :asc
    end

    @collages.execute!
	@my_collages = current_user ? current_user.collages : [] 
    build_bookmarks(Collage, "ItemCollage")

    respond_to do |format|
	  #The following is called via normal page load
	  # and via AJAX.
      format.html do
	    if request.xhr?
		  render :partial => 'collages_block'
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

    respond_to do |format|
      format.html do
	    @can_edit = current_user && @collage.users.include?(current_user)
	    render 'show'
	  end # show.html.erb
      format.xml  { render :xml => @collage }
	  format.pdf do
	    url = request.url.gsub(/\.pdf.*/, "/export/#{params[:state_id]}")
		file = Tempfile.new('collage.pdf')
	    cmd = "#{RAILS_ROOT}/wkhtmltopdf #{url} - > #{file.path}"
		system(cmd)
		file.close
		send_file file.path, :filename => "collage_#{@collage.id}.pdf", :type => 'application/pdf'
		#file.unlink
		#Removing saved state after used
		ReadableState.delete(params[:state_id])
	  end
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
	    format.json { render :json => { :type => 'collages', :id => @collage.id } }
      else
        flash[:notice] = "We couldn't create that collage - " + @collage.errors.full_messages.join(',')
        format.html { render :action => "new" }
        format.xml  { render :xml => @collage.errors, :status => :unprocessable_entity }
	    format.json { render :json => { :type => 'collages', :id => @collage.id } }
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

  def record_collage_print_state
    #NOTE: Initially, recording printable collage state was
	#attempted to be done by session, but the command line
	#wkhtmltopdf was not loading the current user session,
	#and therefore was unable to retrieve the current user
	#collage readable state
    begin
      readable_state = ReadableState.new(:state => params[:state])
      readable_state.save
	  respond_to do |format|
	    format.json { render :json => { :id => readable_state.id } }
	  end
    rescue Exception => e
	  respond_to do |format|
	    format.json { render :json => {} }
	  end
	end
	
    session[:current_print] = params[:state]
  end

  def save_readable_state
	@collage.update_attribute('readable_state', params[:v])
	respond_to do |format|
	  format.json { render :json => { :time => Time.now.to_s(:simpledatetime) } }
	end
  end

  def export
    if params[:state_id]
      @readable_state = ReadableState.find(params[:state_id]).state
	else
	  @readable_state = @collage.readable_state
	end
    render :layout => 'pdf'
  end

  private 

  def is_collage_admin
    if current_user
      @is_collage_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','collage_admin','superadmin']}).length > 0
    end
  end

  def load_collage
    @collage = Collage.find((params[:id].blank?) ? params[:collage_id] : params[:id], :include => [:accepted_roles => {:users => true}, :annotations => {:layers => true}])
  end
end
