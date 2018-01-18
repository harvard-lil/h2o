class UsersController < ApplicationController
  cache_sweeper :user_sweeper
  protect_from_forgery
  layout 'main', only: [:new, :create, :show, :edit, :update]

  def new
    @user = User.new params.fetch(:user, {}).permit(:email_address, :attribution)
  end

  def index
    redirect_to search_path(type: 'users')
    # common_index User
  end

  def verify
    if current_user.present? && current_user == User.where(id: params[:id]).first && params[:token] == current_user.perishable_token
      current_user.update_column(:verified_email, true)
      flash[:notice] = 'Thank you. Your account has been verified. You may now contribute to H2O.'
      redirect_to user_path(current_user)
    elsif current_user.present?
      flash[:notice] = 'Your account has not been verified. Please try again by requesting an email verification <a href="' + verify_user_url(current_user)  + '" target="blank">here</a>.'
      redirect_to user_path(current_user)
    else
      flash[:notice] = 'Your account has not been verified. Please login and try visiting the link in the email again.'
      redirect_to '/user_sessions/new'
    end
  end

  def create
    @user = User.new(permitted_user_params)

    if @user.save
      @user.send_verification_request
      flash[:success] = I18n.t('users.sign-up.flash.success.html').html_safe
      redirect_to user_path(@user)
    else
      render :action => :new
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
    end

    if @user.update_attributes(user_params)
      flash[:success] = 'Profile updated.'
      redirect_to edit_user_path(@user)
    else
      render :edit
    end
  end

  def user_lookup
    @users = User.where("(email_address = ? OR login = ?) AND id != ?", params[:lookup], params[:lookup], current_user.id).collect { |u| { :display => "#{u.login} (#{u.email_address})", :id => u.id } }
    render :json => { :items => @users }
  end

  private
  def permitted_user_params
    permitted_fields = [:id, :name, :login, :password, :password_confirmation,
                                  :current_password, :image,
                                 :email_address, :tz_name, :attribution, :title,
                                 :url, :affiliation, :description, :terms, :professor_verification_requested]
    if Rails.configuration.disable_verification
      permitted_fields.push :verified_email
    end
    params.fetch(:user, {}).permit(*permitted_fields)
  end
end
