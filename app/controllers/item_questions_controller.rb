class ItemQuestionsController < ApplicationController
  #FIXME - ensure only owners can add items to playlists

  # POST /item_questions
  # POST /item_questions.xml
  def create
    @item_question = ItemQuestion.new(params[:item_question])

    container_id = params[:container_id]

    respond_to do |format|
      if @item_question.save
        @item_question.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist_id => container_id)
        playlist_item.resource_item = @item_question

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'ItemDefault was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@item_question) }
        format.xml  { render :xml => @item_question, :status => :created, :location => @item_question }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @item_question.errors, :status => :unprocessable_entity }
      end
    end
  end

  def new
    render :text => '', :status => 500
  end

  # PUT /item_questions/1
  # PUT /item_questions/1.xml
  def update
    @item_question = ItemQuestion.find(params[:id])

    respond_to do |format|
      if @item_question.update_attributes(params[:item_question])
        flash[:notice] = 'Itemquestion was successfully updated.'
        format.html { render :text => nil }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @item_question.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /item_questions/1
  # DELETE /item_questions/1.xml
  def destroy
    @item_question = ItemQuestion.find(params[:id])
    @item_question.destroy

    respond_to do |format|
      format.html { redirect_to(item_questions_url) }
      format.xml  { head :ok }
    end
  end
end
