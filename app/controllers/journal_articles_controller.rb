class JournalArticlesController < BaseController
  before_filter :require_user, :except => [:show]
  before_filter :load_journal_article, :only => [:update, :destroy, :show]

  access_control do
    allow all, :to => [:create, :show]
    allow :journal_article_admin, :admin, :superadmin
    allow :owner, :of => :journal_article, :to => [:destroy, :edit, :update]
  end

  def show
  end

  def create
    unless params[:journal_article][:tag_list].blank?
      params[:journal_article][:tag_list] = params[:journal_article][:tag_list].downcase
    end

    @journal_article = JournalArticle.new(params[:journal_article])

    if @journal_article.save
      @journal_article.accepts_role!(:owner, current_user)
      @journal_article.accepts_role!(:creator, current_user)
      flash[:notice] = 'Text Block was successfully created.'
      redirect_to "/journal_articles/#{@journal_article.id}"
    else
      add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor', 'new_text_block']
      add_stylesheets ['new_text_block']

      @text_block = TextBlock.new
      @text_block.build_metadatum
      render :action => "new"
    end
  end

  def update
    unless params[:journal_article][:tag_list].blank?
      params[:journal_article][:tag_list] = params[:journal_article][:tag_list].downcase
    end

    if @journal_article.update_attributes(params[:journal_article])
      flash[:notice] = 'Text Block was successfully updated.'
      redirect_to "/journal_articles/#{@journal_article.id}"
    else
      add_javascripts ['tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor', 'new_text_block']
      add_stylesheets ['new_text_block']
      render :action => "edit"
    end
  end

  def destroy
    @journal_article.destroy
    respond_to do |format|
      format.html { redirect_to(journal_articles_url) }
      format.xml  { head :ok }
      format.json { render :json => {} }
    end
  end

  private 

  def load_journal_article
    @journal_article = JournalArticle.find((params[:id].blank?) ? params[:journal_article_id] : params[:id])
  end
end
