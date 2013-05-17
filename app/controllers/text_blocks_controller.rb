class TextBlocksController < BaseController
  cache_sweeper :text_block_sweeper

  before_filter :require_user, :except => [:index, :show, :metadata, :embedded_pager, :export]
  before_filter :load_single_resource, :only => [:show, :edit, :update, :destroy, :export]
  before_filter :store_location, :only => [:index, :show]

  before_filter :create_brain_buster, :only => [:new]
  before_filter :validate_brain_buster, :only => [:create]
  before_filter :restrict_if_private, :only => [:show, :edit, :update, :destroy, :embedded_pager, :export]
  access_control do
    allow all, :to => [:show, :index, :metadata, :autocomplete_tags, :new, :create, :embedded_pager, :export]
    allow :text_block_admin, :admin, :superadmin
    allow :owner, :of => :text_block, :to => [:destroy, :edit, :update]
  end

  def show
  end

  def export
    render :layout => 'print'
  end

  # GET /text_blocks/1/edit
  def edit
    add_javascripts ['visibility_selector', 'new_text_block', 'tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_text_block']

    if @text_block.metadatum.blank?
      @text_block.build_metadatum
    end
  end

  def metadata
    #FIXME
  end

  def embedded_pager
    super TextBlock
  end

  # GET /text_blocks/new
  def new
    add_javascripts ['visibility_selector', 'new_text_block', 'tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_text_block']

    @text_block = TextBlock.new
    @text_block.build_metadatum
    @journal_article = JournalArticle.new
  end

  def create
    unless params[:text_block][:tag_list].blank?
      params[:text_block][:tag_list] = params[:text_block][:tag_list].downcase
    end

    @text_block = TextBlock.new(params[:text_block])
    @journal_article = JournalArticle.new

    if @text_block.save
      @text_block.accepts_role!(:owner, current_user)
      @text_block.accepts_role!(:creator, current_user)
      flash[:notice] = 'Text Block was successfully created.'
      redirect_to "/text_blocks/#{@text_block.id}"
    else
      add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor', 'new_text_block']
      add_stylesheets ['new_text_block']

      @text_block.build_metadatum
      render :action => "new"
    end
  end

  # GET /text_blocks
  def index
    common_index TextBlock
  end

  def autocomplete_tags
    render :json => TextBlock.autocomplete_for(:tags,params[:tag])
  end

  def update
    unless params[:text_block][:tag_list].blank?
      params[:text_block][:tag_list] = params[:text_block][:tag_list].downcase
    end

    if @text_block.update_attributes(params[:text_block])
      flash[:notice] = 'Text Block was successfully updated.'
      redirect_to "/text_blocks/#{@text_block.id}"
    else
      add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor', 'new_text_block']
      add_stylesheets ['new_text_block']
      render :action => "edit"
    end
  end

  # DELETE /text_blocks/1
  def destroy
    @text_block.destroy
    render :json => {}
  end

  def render_or_redirect_for_captcha_failure
    add_javascripts ['new_text_block', 'tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_text_block']

    @text_block = TextBlock.new(params[:text_block])
    @text_block.build_metadatum
    @text_block.valid?
    @journal_article = JournalArticle.new
    create_brain_buster
    render :action => "new"
  end
end
