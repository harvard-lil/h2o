class CollagesController < BaseController

  cache_sweeper :collage_sweeper

  before_filter :is_collage_admin, :except => [:embedded_pager, :metadata]
  before_filter :require_user, :except => [:layers, :annotations, :index, :show, :metadata, :description_preview, :embedded_pager, :export, :record_collage_print_state]
  before_filter :load_collage, :only => [:layers, :show, :edit, :update, :destroy, :undo_annotation, :spawn_copy, :save_readable_state, :export, :record_collage_print_state]
  before_filter :list_tags, :only => [:index, :show, :edit, :new]

  caches_action :annotations

  access_control do
    allow all, :to => [:layers, :annotations, :index, :show, :new, :create, :metadata, :description_preview, :spawn_copy, :embedded_pager, :export, :record_collage_print_state]    
    allow :owner, :of => :collage, :to => [:destroy, :edit, :update, :save_readable_state]
    allow :admin, :collage_admin, :superadmin
  end

  def list_tags
    @collage_tags = Tag.find_by_sql("SELECT ts.tag_id AS id, t.name FROM taggings ts
		JOIN tags t ON ts.tag_id = t.id
		WHERE taggable_type = 'Collage'
		GROUP BY ts.tag_id, t.name
		ORDER BY COUNT(*) DESC LIMIT 25")
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
      data_accessor_for(Collage).include = {:annotations => {:layers => []}, :accepted_roles => {}, :annotatable => {}}
	  order_by params[:sort].to_sym, :asc
    end

    @collages.execute!
	@my_collages = current_user ? current_user.collages : [] 
    build_bookmarks("ItemCollage")

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
    add_javascripts ['collages', 'markitup/jquery.markitup.js','markitup/sets/textile/set.js','markitup/sets/html/set.js', 'jquery.tipsy']
    add_stylesheets ['/javascripts/markitup/skins/markitup/style.css','/javascripts/markitup/sets/textile/style.css', 'collages']

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @collage }
	  format.pdf do
	    logger.warn "steph: #{params.inspect}"
	    url = request.url.gsub(/\.pdf/, '/export')
		logger.warn "steph: #{url}"
		require 'tempfile'
		file = Tempfile.new('collage.pdf')
	    cmd = "#{RAILS_ROOT}/wkhtmltopdf #{url} - > #{file.path}"
		system(cmd)
		file.close
		send_file file.path, :filename => "collage#{@collage.id}.pdf", :type => 'application/pdf'
		#file.unlink
        #session.delete(:current_print)
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
    session[:current_print] = params[:state]
	respond_to do |format|
	  format.json { render :json => {} }
	end
  end

  def save_readable_state
	@collage.update_attribute('readable_state', params[:v])
	respond_to do |format|
	  format.json { render :json => { :time => Time.now.to_s(:simpledatetime) } }
	end
  end

  def export
    add_javascripts ['export_collage']
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
