class UserCollectionsController < BaseController
  protect_from_forgery :except => [:destroy, :update]

  def load_user_collection
  end

  def new
    respond_to do |format|
      format.html 
    end
  end

  def edit
  end

  def destroy
    @user_collection.destroy

    render :json => {}
  end

  def manage_users
  end

  def manage_playlists
  end

  def manage_collages
  end

  def manage_permissions
    @permissions = { :playlist => [], :collage => [] }
    Permission.all.sort_by { |p| p.id }.each do |p|
      @permissions[p.permission_type.to_sym] << p if p.permission_type
    end

    @user_permission_map = @user_collection.permission_assignments.map { |pa| "#{pa.user_id}_#{pa.permission_id}" }
  end

  def create
    params[:user_collection][:owner_id] = @current_user.id
    user_collection = UserCollection.new(user_collections_params)

    if user_collection.save
      render :json => { :error => false, :type => "users", :id => current_user.id }
    else
      render :json => { :error => true, :message => "#{user_collection.errors.full_messages.join(',')}" }
    end
  end

  def update_permissions
    begin
      params[:permission_assignments] ||= {}

      arr = []
      # First set specific items to destroy, or don't touch unchanged items
      @user_collection.permission_assignments.each do |pa|
        h = { "id" => pa.id, "user_id" => pa.user_id, "permission_id" => pa.permission_id, "_destroy" => "1" }
        if params[:permission_assignments].has_key?(pa.user_id.to_s)
          if params[:permission_assignments][pa.user_id.to_s].include?(pa.permission_id.to_s)
            params[:permission_assignments][pa.user_id.to_s].delete(pa.permission_id.to_s)
            h.delete("_destroy")
          end
        end
        arr.push(h)
      end

      # Next, add new items
      params[:permission_assignments].each do |k, v|
        v.each do |p|
          arr.push({ "user_id" => k, "permission_id" => p })
        end
      end

      @user_collection.attributes = { :permission_assignments_attributes => arr }
      if @user_collection.save
        render :json => { :error => false, :id => @user_collection.id, :custom_block => "updated_permissions" }
      else
        render :json => { :error => true, :message => "#{@user_collection.errors.full_messages.join(',')}" }
      end
    rescue Exception => e
      render :json => { :error => true, :message => "Failed to update. Please try again." }
    end
  end

  def update
    if !params.has_key?(:user_collection)
      params[:user_collection] = {}
    end
    if params.has_key?(:manage_users) && !params[:user_collection].has_key?(:user_ids)
      params[:user_collection][:user_ids] = []
    elsif params.has_key?(:manage_playlists) && !params[:user_collection].has_key?(:playlist_ids)
      params[:user_collection][:playlist_ids] =[]
    elsif params.has_key?(:manage_collages) && !params[:user_collection].has_key?(:collage_ids)
      params[:user_collection][:collage_ids] = []
    end

    if params.has_key?(:manage_users)
      # Permission Assignment Updates based on user updates
      arr = []
      @user_collection.permission_assignments.each do |pa|
        h = { "id" => pa.id, "user_id" => pa.user_id, "permission_id" => pa.permission_id }
        if !params[:user_collection][:user_ids].include?(pa.user_id)
          h["_destroy"] = "1"
        end
        arr.push(h)
      end
      params[:user_collection][:permission_assignments_attributes] = arr
    end

    if @user_collection.update_attributes(user_collections_params)
      render :json => { :error => false, :type => "users", :id => current_user.id }
    else
      render :json => { :error => true, :message => "#{@user_collection.errors.full_messages.join(',')}" }
    end
  end
  
  private
  def user_collections_params
    params.require(:user_collection).permit(:name, 
                                            :description, 
                                            :owner_id, 
                                            permission_assignments_attributes: [:id, :user_id, :permission_id, :_destroy], 
                                            :user_ids => [], 
                                            :playlist_ids => [],
                                            :collage_ids => [])
  end
end
