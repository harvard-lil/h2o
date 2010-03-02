class QuestionsController < BaseController

  before_filter :prep_resources

  def vote_for
    begin
      q = Question.find(params[:question_id])
      current_user.vote_for(q)
      render :text => '<p>Vote tallied!</p>', :layout => false
    rescue Exception => e
      #you fail it.
      render :text => "We're sorry, we couldn't record that vote. You might've already voted for this item.", 
        :status => :internal_server_error
    end
  end

  # GET /questions/1
  # GET /questions/1.xml
  def show
    @question = Question.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @question }
    end
  end

  # GET /questions/new
  # GET /questions/new.xml
  def new
    add_stylesheets ["formtastic","forms"]
    @question = Question.new

    begin
      @question.question_instance_id = params[:question][:question_instance_id]
    rescue Exception => e
      @question.question_instance = QuestionInstance.default_instance
    end

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @question }
    end
  end

  # GET /questions/1/edit
  def edit
    add_stylesheets ["formtastic","forms"]
    @question = Question.find(params[:id])
  end

  # POST /questions
  # POST /questions.xml
  def create
    add_stylesheets ["formtastic","forms"]
    @question = Question.new(params[:question])

    respond_to do |format|
      @question.user = current_user
      if @question.save
        format.html { render :text => @question.id, :layout => false }
        format.xml  { render :xml => @question, :status => :created, :location => @question }
      else
        format.html { render :text => "We couldn't add that question. Sorry!<br/> #{@question.errors.full_messages.join('<br/')}", :status => :unprocessable_entity }
        format.xml  { render :xml => @question.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /questions/1
  # PUT /questions/1.xml
  def update
    add_stylesheets ["formtastic","forms"]
    @question = Question.find(params[:id])

    respond_to do |format|
      if @question.update_attributes(params[:question])
        flash[:notice] = 'Question was successfully updated.'
        format.html { redirect_to(@question) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @question.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /questions/1
  # DELETE /questions/1.xml
  def destroy
    @question = Question.find(params[:id])
    @question.destroy

    respond_to do |format|
      format.html { redirect_to(questions_url) }
      format.xml  { head :ok }
    end
  end

  private
  
  def prep_resources

  end
end
