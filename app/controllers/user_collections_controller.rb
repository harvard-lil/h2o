class UserCollectionsController < BaseController
  #before_filter :require_user, :except => [:layers, :index, :show, :description_preview, :embedded_pager, :export, :export_unique, :access_level]
  before_filter :load_user_collection, :only => [:edit, :manage_users, :manage_playlists, :manage_collages, :manage_permissions, :update_permissions, :destroy, :update]

  def load_user_collection
    @user_collection = UserCollection.find(params[:id])
  end

  def new
    @user_collection = UserCollection.new

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
      @permissions[p.permission_type.to_sym] << p
    end

    @user_permission_map = @user_collection.permission_assignments.map { |pa| "#{pa.user_id}_#{pa.permission_id}" }
  end

  def create
    params[:user_collection][:owner_id] = @current_user.id
    user_collection = UserCollection.new(params[:user_collection])

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
    if params.has_key?(:manage_users)
      if !params.has_key?(:user_collection)
        params[:user_collection] = { :user_ids => [] }
      end

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

    params[:user_collection][:owner_id] = @current_user.id
    @user_collection.attributes = params[:user_collection]

    if @user_collection.save
      render :json => { :error => false, :type => "users", :id => current_user.id }
    else
      render :json => { :error => true, :message => "#{@user_collection.errors.full_messages.join(',')}" }
    end
  end
end
