class QuestionInstancesController < BaseController

  cache_sweeper :question_instance_sweeper
  caches_action :updated, :cache_path => Proc.new {|c| "updated-at-#{c.params[:id]}"}
  caches_action :metadata, :cache_path => Proc.new {|c| "question-instance-metadata-#{c.params[:id] || c.params[:question_instance_id]}"}

  before_filter :require_user, :except => [:index, :last_updated_questions, :updated, :show, :metadata, :embedded_pager]
  before_filter :prep_resources, :except => [:index, :metadata, :embedded_pager]
  before_filter :load_single_resource, :only => [:destroy, :edit, :update, :metadata]

  after_filter :update_question_instance_time

  access_control do
    allow all, :to => [:index, :updated, :last_updated_questions, :is_owner, :show, :new, :create, :metadata, :embedded_pager]
    allow :admin
    allow :owner, :of => :question_instance, :to => [:destroy, :edit, :update]
  end

  rescue_from Acl9::AccessDenied do |exception|
    redirect_to :action => :index
  end

  def embedded_pager
    super QuestionInstance
  end

  def metadata
    @question_instance[:object_type] = h @question_instance.class.to_s
    @question_instance[:child_object_name] = 'question'
    @question_instance[:child_object_plural] = 'questions'
    @question_instance[:child_object_count] = h @question_instance.question_count
    @question_instance[:child_object_type] = 'Question'
    @question_instance[:child_object_ids] = @question_instance.root_question_ids
    @question_instance[:title] = h @question_instance.name
    render :xml => @question_instance.to_xml(:skip_types => true)
  end

  # GET /question_instances
  # GET /question_instances.xml
  def index
    @question_instances = QuestionInstance.find(:all, :include => [:questions], :order => :id)
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
  end

  # GET /question_instances/new
  # GET /question_instances/new.xml
  def new
    @question_instance = QuestionInstance.new
  end

  # GET /question_instances/1/edit
  def edit
  end

  # POST /question_instances
  # POST /question_instances.xml
  def create
    @question_instance = QuestionInstance.new(params[:question_instance])
    respond_to do |format|
      if @question_instance.save
        @question_instance.accepts_role!(:owner, current_user)
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
    redirect_to(question_instances_url) 
  end

  private

  def prep_resources
    @logo_title = 'Question Tool'
  end

end
