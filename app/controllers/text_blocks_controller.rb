class TextBlocksController < BaseController
  cache_sweeper :text_block_sweeper
  protect_from_forgery :except => [:export, :export_all, :export_as, :destroy]
  before_action :limit_missing_item, :only => :destroy

  def show
  end

  def export
    @item = @text_block
    render :layout => 'print'
  end

  def edit
  end

  def embedded_pager
    super TextBlock
  end

  def new
    @text_block = TextBlock.new
    @text_block.build_metadatum
    @page_title = "New Text"
  end

  def create
    @text_block = TextBlock.new(text_blocks_params)
    @text_block.user = current_user
    verify_captcha(@text_block)

    if @text_block.save
      flash[:notice] = 'Text Block was successfully created.'
      redirect_to "/text_blocks/#{@text_block.id}"
    else
      render :action => "new"
    end
  end

  def index
    common_index TextBlock
  end

  def update
    # versionif
    if @text_block.update_attributes(text_blocks_params)
      flash[:notice] = 'Text Block was successfully updated.'
      redirect_to "/text_blocks/#{@text_block.id}"
    else
      render :action => "edit"
    end
  end

  def destroy
    @text_block.destroy
    render :json => {}
  end

  private
  def text_blocks_params
    params.require(:text_block).permit(:id, :name, :public, :description, :tag_list, :content, :version,
                                       :enable_feedback, :enable_discussions, :enable_responses,
                                       metadatum_attributes: [:contributor, :coverage, :creator, :date,
                                                              :description, :format, :identifier, :language,
                                                              :publisher, :relation, :rights, :source,
                                                              :subject, :title, :dc_type, :classifiable_type,
                                                              :classifiable_id ])
  end
end
