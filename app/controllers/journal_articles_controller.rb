class JournalArticlesController < BaseController
  before_filter :require_user, :except => [:show, :export]
  before_filter :load_single_resource, :only => [:update, :destroy, :show, :export, :edit]

  access_control do
    allow all, :to => [:create, :show, :export]
    allow :journal_article_admin, :admin, :superadmin
    allow :owner, :of => :journal_article, :to => [:destroy, :edit, :update]
  end

  def show
    @display_map = [{ :key => :author, :display => "Author" },
                    { :key => :author_description, :display => "Short statement about the author" },
                    { :key => :publish_date, :display => "Publish Date" },
                    { :key => :volume, :display => "Volume #" },
                    { :key => :issue, :display => "Issue #" },
                    { :key => :page, :display => "Page #" },
                    { :key => :bluebook_citation, :display => "Bluebook Citation" },
                    { :key => :article_type, :display => "Article Type" },
                    { :key => :article_series_title, :display => "Article Series Title" },
                    { :key => :article_series_description, :display => "Article Series Description" },
                    { :key => :pdf_url, :display => "URL Link for PDF of Article" },
                    { :key => :image, :display => "Image" },
                    { :key => :attribution, :display => "Attribution" },
                    { :key => :attribution_url, :display => "URL Link for Attribution" },
                    { :key => :video_embed, :display => "Video Emed" }]
    add_stylesheets 'journal_articles'
  end

  def export
    render :layout => 'print'
  end

  def edit
    add_javascripts ['new_text_block', 'tiny_mce/tiny_mce.js', 'h2o_wysiwig', 'switch_editor']
    add_stylesheets ['new_text_block']
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
end
