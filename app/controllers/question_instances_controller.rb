class QuestionInstancesController < BaseController

  cache_sweeper :question_instance_sweeper
  caches_action :updated, :cache_path => Proc.new {|c| "updated-at-#{c.params[:id]}"}
#  caches_action :last_updated_question, :cache_path => Proc.new {|c| "last-updated-questions-#{c.params[:id]}"}

  before_filter :require_user, :except => [:index, :last_updated_questions, :updated, :show]
  before_filter :prep_resources, :except => [:index]
  before_filter :load_question_instance, :only => [:destroy, :edit, :update]

  after_filter :update_question_instance_time

  access_control do
    allow :owner, :of => :question_instance, :to => [:destroy, :edit, :update]
    allow all, :to => [:index, :updated, :last_updated_questions, :is_owner, :show, :new, :create]
  end

  rescue_from Acl9::AccessDenied do |exception|
    redirect_to :action => :index
  end

  # GET /question_instances
  # GET /question_instances.xml
  def index
    add_stylesheets 'question_instances'
    add_stylesheets "tablesorter-blue-theme/style"
    add_javascripts 'question_instances_index'
    add_javascripts "jquery.tablesorter.min"

    @question_instances = QuestionInstance.find(:all, :include => [:questions], :order => :id)

    respond_to do |format|
      format.html { render }
      format.xml  { render :xml => @question_instances }
    end
  end

  def updated
    question_instance = QuestionInstance.find(params[:id])
    render :text => question_instance.updated_at.to_s
  rescue Exception => e
    render :text => 'Unable to update right now. Please try again in a few minutes by refreshing your browser', :status => :service_unavailable
  end

  def last_updated_questions
    updated = Time.parse(params[:time]) + 1.second
    render :json => QuestionInstance.find(params[:id]).questions.roots.find(:all, :conditions => ['updated_at > ?',updated.utc]).collect{|q|q.id}
  rescue Exception => e
    render :json => ''
  end

  def is_owner
    question_instance = QuestionInstance.find(params[:id])
    render :json => current_user.has_role?(:owner, question_instance)
  rescue Exception => e
    render :text => "Sorry, there's been an error", :status => :server_error
  end

  # GET /question_instances/1
  # GET /question_instances/1.xml
  def show
    if params[:sort].blank?
      params[:sort] = cookies[:sort]
    end
    @question_instance = QuestionInstance.find(params[:id])

    respond_to do |format|
      format.html { render } 
      format.xml  { render :xml => @question_instance }
    end
  end

  # GET /question_instances/new
  # GET /question_instances/new.xml
  def new
    add_stylesheets ["formtastic","forms"]
    @question_instance = QuestionInstance.new

    respond_to do |format|
      format.js { render :partial => 'shared/forms/question_instance' } 
      format.html { render } 
      format.xml  { render :xml => @question_instance }
    end
  end

  # GET /question_instances/1/edit
  def edit
    add_stylesheets ["formtastic","forms"]
    respond_to do |format|
      format.html { render :partial => 'shared/forms/question_instance' } 
      format.xml  { render :xml => @question_instance }
    end
  end

  # POST /question_instances
  # POST /question_instances.xml
  def create
    add_stylesheets ["formtastic","forms"]
    @question_instance = QuestionInstance.new(params[:question_instance])
    @question_instance.accepts_role!(:owner, current_user)
    respond_to do |format|
      if @question_instance.save
        @UPDATE_QUESTION_INSTANCE_TIME = @question_instance
        flash[:notice] = 'QuestionInstance was successfully created.'
        format.html { 
          if request.xhr?
            render :text => @question_instance.id 
          else
            redirect_to question_instances_path
          end
        }
        format.xml  { render :xml => @question_instance, :status => :created, :location => @question_instance }
      else
        format.html { 
          if request.xhr?
            render :text => "We couldn't add that question instance. Sorry!<br/>#{@question_instance.errors.full_messages.join('<br/')}", :status => :unprocessable_entity 
          else
            render :action => :new
          end
        }
        format.xml  { render :xml => @question_instance.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /question_instances/1
  # PUT /question_instances/1.xml
  def update
    add_stylesheets ["formtastic","forms"]
    @question_instance = QuestionInstance.find(params[:id])

    respond_to do |format|
      if @question_instance.update_attributes(params[:question_instance])
        @UPDATE_QUESTION_INSTANCE_TIME = @question_instance
        flash[:notice] = 'Question Instance was successfully updated.'
        format.html { render :text => @question_instance.id }
        format.xml  { head :ok }
      else
        format.html { render :text => "We couldn't update that question instance. Sorry!<br/>#{@question_instance.errors.full_messages.join('<br/')}", :status => :unprocessable_entity }
        format.xml  { render :xml => @question_instance.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /question_instances/1
  # DELETE /question_instances/1.xml
  def destroy
    @question_instance.destroy

    respond_to do |format|
      format.html { redirect_to(question_instances_url) }
      format.xml  { head :ok }
    end
  end

  private

  def load_question_instance
    @question_instance = QuestionInstance.find(params[:id])
  end

  def prep_resources
    @logo_title = 'Question Tool'
    add_stylesheets 'question_instances'
    add_javascripts 'question_instances'
  end

end
