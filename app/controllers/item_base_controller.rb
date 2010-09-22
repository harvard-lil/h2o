class ItemBaseController < BaseController

  before_filter :set_model

  def create
    @object = @model_class.new(params[@param_symbol])

    container_id = params[:container_id]

    respond_to do |format|
      if @object.save
        @object.accepts_role!(:owner, current_user)

        playlist_item = PlaylistItem.new(:playlist_id => container_id)
        playlist_item.resource_item = @object

        if playlist_item.save!
          playlist_item.accepts_role!(:owner, current_user)
        end

        flash[:notice] = 'ItemDefault was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@object) }
        format.xml  { render :xml => @object, :status => :created, :location => @object }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @object.errors, :status => :unprocessable_entity }
      end
    end
  end

  def new
    render :text => '', :status => 500
  end

  def update
    @object = @model_class.find(params[:id])

    respond_to do |format|
      if @object.update_attributes(params[@param_symbol])
        flash[:notice] = "#{@model_class.name.titleize} was successfully updated."
        format.html { render :text => nil }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @object.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @object = @model_class.find(params[:id])
    @object.destroy

    respond_to do |format|
      format.html { redirect_to(item_cases_url) }
      format.xml  { head :ok }
    end
  end

  private
  
  def set_model
    @model_class = controller_class_name.gsub(/Controller/,'').singularize.constantize
    @param_symbol = @model_class.name.tableize.singularize.to_sym
  end

end
