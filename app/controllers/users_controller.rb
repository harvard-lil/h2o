class UsersController < ApplicationController
  cache_sweeper :user_sweeper
  protect_from_forgery
  layout 'main', only: [:new, :create, :show, :edit, :update]

  def new
    @user = User.new params.fetch(:user, {}).permit(:email_address, :attribution)
  end

  def index
    redirect_to search_path(type: 'users')
  end

  def create
    user_params = permitted_user_params
    temporary_password = Random.new_seed
    user_params["password"] = temporary_password
    user_params["password_confirmation"] = temporary_password
    @user = User.new(user_params)

    if @user.save_without_session_maintenance
      @user.send_verification_request
      redirect_to root_path,
                  flash: {success: I18n.t('users.sign-up.flash.success.html').html_safe}
    else
      render :new
    end
  end

  def request_anon
    @user = User.new
  end

  def show
    @user = User.find_by_id(params[:id])
    if !@user
      redirect_to :root and return
    end
    render 'content/dashboard'
  end

  def edit
    if current_user
      @user = current_user
    end
  end

  def update
    @user = @current_user
    user_params = permitted_user_params

    if user_params[:password].present? && !@user.valid_password?(user_params[:current_password])
      flash[:error] = "Current password is incorrect."
      return render :edit
    end
    user_params.delete :current_password

    if user_params[:professor_verification_requested] == "1" && !@user.professor_verification_requested
      @user.send_professor_verification_request_to_admin
      @user.update(professor_verification_requested: true) 
    end

    if @user.update_attributes(user_params)
      flash[:success] = 'Profile updated.'
      redirect_to edit_user_path(@user)
    else
      render :edit
    end
  end

  def user_lookup
    @users = User.where("(email_address = ? OR login = ? OR attribution = ? OR title = ? or id = ? )", params[:lookup], params[:lookup], current_user.id).collect { |u| { :display => "#{u.login} (#{u.email_address}) (#{u.attribution}) (#{u.title}) (#{u.id})", :id => u.id } }
    render :json => { :items => @users }
  end

  private
  def permitted_user_params
    permitted_fields = [:id, :name, :login, :password, :password_confirmation,
                                  :current_password, :image,
                                 :email_address, :tz_name, :attribution, :title,
                                 :url, :affiliation, :description, :terms, :professor_verification_requested]
    params.fetch(:user, {}).permit(*permitted_fields)
  end
end
