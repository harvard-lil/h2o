class TextBlocksController < BaseController
  before_filter :prep_resources
  before_filter :my_text_blocks, :only => [:index, :show]
  before_filter :is_text_block_admin, :except => [:embedded_pager, :metadata]
  before_filter :require_user, :except => [:index, :show, :metadata, :embedded_pager]
  before_filter :load_text_block, :only => [:show, :edit, :update, :destroy]

  access_control do
    allow all, :to => [:show, :index, :metadata, :autocomplete_tags, :new, :create, :embedded_pager]
    allow :text_block_manager, :admin, :superadmin
    allow :owner, :of => :text_block, :to => [:destroy, :edit, :update]
  end

  def metadata
    #FIXME
  end

  def embedded_pager
    super TextBlock
  end

  # GET /cases/new
  # GET /cases/new.xml
  def new
    @text_block = TextBlock.new
    @text_block.build_metadatum

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @text_block }
    end
  end


  # POST /text_blocks
  # POST /text_blocks.xml
  def create

    unless params[:text_block][:tag_list].blank?
      params[:text_block][:tag_list] = params[:text_block][:tag_list].downcase
    end

    @text_block = TextBlock.new(params[:text_block])

    respond_to do |format|
      if @text_block.save
        @text_block.accepts_role!(:owner, current_user)
        @text_block.accepts_role!(:creator, current_user)
        flash[:notice] = 'Text Block was successfully created.'
        format.html { redirect_to(text_blocks_url) }
        format.xml  { render :xml => @text_block, :status => :created, :location => @text_block }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @text_block.errors, :status => :unprocessable_entity }
      end
    end
  end

  # GET /text_blocks
  # GET /text_blocks.xml
  def index
    @text_blocks = Sunspot.new_search(TextBlock)

    @text_blocks.build do
      unless params[:keywords].blank?
        keywords params[:keywords]
      end
      with :public, true
      with :active, true
      paginate :page => params[:page], :per_page => cookies[:per_page] || nil
      data_accessor_for(TextBlock).include = [:metadatum, :collages]
      order_by :display_name, :asc
    end

    if params[:tags]

      if params[:any] 
        @text_blocks.build do
          any_of do
            params[:tags].each do|t|
              with :tag_list, t
            end
          end
        end

      else
        @text_blocks.build do
          params[:tags].each do|t|
            with :tag_list, t
          end
        end
      end

    end

    @text_blocks.execute!

    respond_to do |format|
      format.html # index.html.erb
      format.js { render :partial => 'text_block_list' }
      format.xml  { render :xml => @text_blocks }
    end
  end

  def autocomplete_tags
    render :json => TextBlock.autocomplete_for(:tags,params[:tag])
  end

  def is_text_block_admin
    if current_user
      @is_text_block_admin = current_user.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','text_block_admin','superadmin']}).length > 0
    end
  end

  def my_text_blocks
    if current_user
      @my_text_blocks = current_user.text_blocks
    end
  end

  def load_text_block
    @text_block = TextBlock.find((params[:id].blank?) ? params[:text_block_id] : params[:id])
  end

  def prep_resources
    add_javascripts ['jquery.tablesorter.min']
    add_stylesheets ['tablesorter-h2o-theme/style']
  end

end
