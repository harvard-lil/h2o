class RepliesController < BaseController

  before_filter :prep_resources

  # GET /replies
  # GET /replies.xml
  def index
    @replies = Reply.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @replies }
    end
  end

  # GET /replies/1
  # GET /replies/1.xml
  def show
    @reply = Reply.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @reply }
    end
  end

  # GET /replies/new
  # GET /replies/new.xml
  def new
    begin
      @reply = Reply.new
      @reply.question_id = params[:reply][:question_id]
      @reply.user = current_user
      respond_to do |format|
        format.html { render :layout => false } 
        format.xml  { render :xml => @reply }
      end
    rescue Exception => e
      render :text => "Sorry! We couldn't figure out what you wanted to reply to.", :status => :internal_server_error
    end
  end

  # GET /replies/1/edit
  def edit
    @reply = Reply.find(params[:id])
  end

  # POST /replies
  # POST /replies.xml
  def create
    @reply = Reply.new(params[:reply])

    respond_to do |format|
      if @reply.save
        flash[:notice] = 'Reply was successfully created.'
        format.html { redirect_to(@reply) }
        format.xml  { render :xml => @reply, :status => :created, :location => @reply }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @reply.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /replies/1
  # PUT /replies/1.xml
  def update
    @reply = Reply.find(params[:id])

    respond_to do |format|
      if @reply.update_attributes(params[:reply])
        flash[:notice] = 'Reply was successfully updated.'
        format.html { redirect_to(@reply) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @reply.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /replies/1
  # DELETE /replies/1.xml
  def destroy
    @reply = Reply.find(params[:id])
    @reply.destroy

    respond_to do |format|
      format.html { redirect_to(replies_url) }
      format.xml  { head :ok }
    end
  end

  private
  
  def prep_resources

  end
end
