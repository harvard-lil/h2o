class QuestionsController < BaseController

  cache_sweeper :question_sweeper

  before_filter :prep_resources

  before_filter :require_user, :except => [:replies]
  before_filter :load_question, :only => [:destroy, :toggle_sticky]

  after_filter :update_question_instance_time

  access_control do
    allow :owner, :of => :question_instance, :to => [:destroy, :toggle_sticky]
    allow all, :to => [:replies, :vote_against, :vote_for, :new, :create]
  end

  def toggle_sticky
    if request.post?
      @question.sticky = (@question.sticky) ? false : true
      @question.save
      @UPDATE_QUESTION_INSTANCE_TIME = @question.question_instance
      render :text => @question.id
    end
  rescue Exception => e
    render :text => "There seems to have been a problem: #{e.inspect}", :status => :unprocessable_entity
  end

  def replies
    begin
      @question = Question.find(params[:id])
    rescue Exception => e
      render :text => "We're sorry, we couldn't load the replies for that question." + e.inspect, 
        :status => :internal_server_error
    end
  end

  def vote_against
    vote_engine('against')
  end

  def vote_for
    vote_engine('for')
  end

  # GET /questions/1
  # GET /questions/1.xml
#  def show
#    @question = Question.find(params[:id])
#
#    respond_to do |format|
#      format.html # show.html.erb
#      format.xml  { render :xml => @question }
#    end
#  end

  # GET /questions/new
  # GET /questions/new.xml
  def new
    add_stylesheets ["formtastic","forms"]
    @question = Question.new
    begin
      @question.parent_id = params[:question][:parent_id] || nil
      @question.question_instance_id = params[:question][:question_instance_id]
    rescue Exception => e
      @question.question_instance = QuestionInstance.default_instance
    end
  end

  # GET /questions/1/edit
#  def edit
#    add_stylesheets ["formtastic","forms"]
#    @question = Question.find(params[:id])
#  end

  # POST /questions
  # POST /questions.xml
  def create
    add_stylesheets ["formtastic","forms"]
    @question = Question.new(params[:question])
    @question.parent_id = (@question.parent_id == 0) ? nil : @question.parent_id
    @question.accepts_role!(:asker, current_user)
    respond_to do |format|
      @question.user = current_user
      if @question.save
        @UPDATE_QUESTION_INSTANCE_TIME = @question.question_instance
        format.html { render :text => @question.id }
        format.xml  { render :xml => @question, :status => :created, :location => @question }
      else
        format.html { render :text => "We couldn't add that question. Sorry!<br/>#{@question.errors.full_messages.join('<br/')}", :status => :unprocessable_entity }
        format.xml  { render :xml => @question.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /questions/1
  # PUT /questions/1.xml
#  def update
#    add_stylesheets ["formtastic","forms"]
#    @question = Question.find(params[:id])
#    @UPDATE_QUESTION_INSTANCE_TIME = @question.question_instance
#    respond_to do |format|
#      if @question.update_attributes(params[:question])
#        flash[:notice] = 'Question was successfully updated.'
#        format.html { redirect_to(@question) }
#        format.xml  { head :ok }
#      else
#        format.html { render :action => "edit" }
#        format.xml  { render :xml => @question.errors, :status => :unprocessable_entity }
#      end
#    end
#  end

  # DELETE /questions/1
  # DELETE /questions/1.xml
  def destroy
    @UPDATE_QUESTION_INSTANCE_TIME = @question.question_instance
    @question.destroy
    render :text => "We've deleted that item."
  rescue
    render :text => 'There seems to have been a problem deleting that item.', :status => :unprocessable_entity
  end

  private

  def vote_engine(vote_type = 'for')
    begin
      q = Question.find(params[:question_id])
      if vote_type == 'for'
        current_user.vote_for(q)
      else
        current_user.vote_against(q)
      end
      #update the question instance and the question.
      @UPDATE_QUESTION_INSTANCE_TIME = q.question_instance
      if q.parent_id == nil
        #voted on a root question - ping the update time
        q.updated_at = Time.now
        q.save
      end
      render :text => '<p>Vote tallied!</p>'
    rescue Exception => e
      #you fail it.
      logger.error('Vote failed! Reason:' + e.inspect)
      render :text => "We're sorry, we couldn't record that vote. You might've already voted for this item.", 
        :status => :unprocessable_entity
    end
  end

  def prep_resources

  end

  def load_question
    @question = Question.find(params[:id])
    @question_instance = @question.question_instance
  end

end
