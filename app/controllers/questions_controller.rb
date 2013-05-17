class QuestionsController < BaseController

  cache_sweeper :question_sweeper

  before_filter :require_user, :except => [:replies,:embedded_pager]
  before_filter :load_single_resource, :only => [:destroy, :toggle_sticky]

  after_filter :update_question_instance_time

  access_control do
    allow all, :to => [:replies, :vote_against, :vote_for, :new, :create, :embedded_pager]
    allow :admin
    allow :questions_admin
    allow :owner, :of => :question_instance, :to => [:destroy, :toggle_sticky]
  end

  def embedded_pager
    super Question
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
      @question = Question.find(params[:id] || params[:question_id])
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
    @question = Question.new
    begin
      @question.parent_id = params[:question][:parent_id] || nil
      @question.question_instance_id = params[:question][:question_instance_id]
    rescue Exception => e
      @question.question_instance = QuestionInstance.default_instance
    end
  end

  # POST /questions
  # POST /questions.xml
  def create
    @question = Question.new(params[:question])
    @question.parent_id = (@question.parent_id == 0) ? nil : @question.parent_id
    respond_to do |format|
      @question.user = current_user
      if @question.save
        @question.accepts_role!(:asker, current_user)
        @UPDATE_QUESTION_INSTANCE_TIME = @question.question_instance
        format.html {
          if request.xhr?
            render :text => @question.id 
          else 
            redirect_to question_instance_path(@question.question_instance)
          end
        }
        format.xml  { render :xml => @question, :status => :created, :location => @question }
      else
        format.html { 
          if request.xhr?
          render :text => "We couldn't add that question. Sorry!<br/>#{@question.errors.full_messages.join('<br/')}", :status => :unprocessable_entity 
          else
            render :action => :new
          end
        }
        format.xml  { render :xml => @question.errors, :status => :unprocessable_entity }
      end
    end
  end

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
    q = Question.find(params[:id] || params[:question_id])
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
    if request.xhr?
      render :text => '<p>Vote tallied!</p>'
    else
      redirect_to question_instance_path(q.question_instance)
    end
  rescue Exception => e
    #you fail it.
    logger.error('Vote failed! Reason:' + e.inspect)
    render :text => "We're sorry, we couldn't record that vote. You might've already voted for this item.", 
      :status => :unprocessable_entity
  end
end
