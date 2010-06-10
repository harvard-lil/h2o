class ItemQuestionInstancesController < ApplicationController
  # GET /item_question_instances
  # GET /item_question_instances.xml
  def index
    @item_question_instances = ItemQuestionInstance.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item_question_instances }
    end
  end

  # GET /item_question_instances/1
  # GET /item_question_instances/1.xml
  def show
    @item_question_instance = ItemQuestionInstance.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @item_question_instance }
    end
  end

  # GET /item_question_instances/new
  # GET /item_question_instances/new.xml
  def new
    @item_question_instance = ItemQuestionInstance.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @item_question_instance }
    end
  end

  # GET /item_question_instances/1/edit
  def edit
    @item_question_instance = ItemQuestionInstance.find(params[:id])
  end

  # POST /item_question_instances
  # POST /item_question_instances.xml
  def create
    @item_question_instance = ItemQuestionInstance.new(params[:item_question_instance])

    container_id = params[:container_id]

    respond_to do |format|
      if @item_question_instance.save
        @item_question_instance.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist_id => container_id)
        playlist_item.resource_item = @item_question_instance

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'ItemDefault was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@item_question_instance) }
        format.xml  { render :xml => @item_question_instance, :status => :created, :location => @item_question_instance }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item_question_instance.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /item_question_instances/1
  # PUT /item_question_instances/1.xml
  def update
    @item_question_instance = ItemQuestionInstance.find(params[:id])

    respond_to do |format|
      if @item_question_instance.update_attributes(params[:item_question_instance])
        flash[:notice] = 'ItemQuestionInstance was successfully updated.'
        format.html { redirect_to(@item_question_instance) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item_question_instance.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /item_question_instances/1
  # DELETE /item_question_instances/1.xml
  def destroy
    @item_question_instance = ItemQuestionInstance.find(params[:id])
    @item_question_instance.destroy

    respond_to do |format|
      format.html { redirect_to(item_question_instances_url) }
      format.xml  { head :ok }
    end
  end
end
