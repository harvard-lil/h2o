class UserCollectionsController < BaseController
  #before_filter :require_user, :except => [:layers, :index, :show, :description_preview, :embedded_pager, :export, :export_unique, :access_level]
  before_filter :load_user_collection, :only => [:edit, :manage_users, :destroy, :update]

  #protect_from_forgery :except => [:spawn_copy, :export_unique]

  #access_control do
  #  allow all, :to => [:layers, :index, :show, :new, :create, :spawn_copy, :description_preview, :embedded_pager, :export, :export_unique, :access_level]    
  #  allow :owner, :of => :collage, :to => [:destroy, :edit, :update, :save_readable_state]
  #  allow :admin, :collage_admin, :superadmin
  #end

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

  def create
    params[:user_collection][:owner_id] = @current_user.id
    user_collection = UserCollection.new(params[:user_collection])

    if user_collection.save
      render :json => { :error => false, :type => "users/#{@current_user.id}", :id => "dashboard" }
    else
      render :json => { :error => true, :message => "#{user_collection.errors.full_messages.join(',')}" }
    end
  end

  def update
    if params.has_key?(:manage_users) && !params.has_key?(:user_collection)
      params[:user_collection] = { :user_ids => [] }
    end

    params[:user_collection][:owner_id] = @current_user.id
    @user_collection.attributes = params[:user_collection]

    if @user_collection.save
      render :json => { :error => false, :type => "users/#{@current_user.id}", :id => "dashboard" }
    else
      render :json => { :error => true, :message => "#{@user_collection.errors.full_messages.join(',')}" }
    end
  end
end
