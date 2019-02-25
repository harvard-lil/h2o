class PasswordResetsController < ApplicationController
  before_action :load_user_using_perishable_token, :only => [:edit, :update]
  layout 'main', only: [:new, :create, :edit, :update]

  def new
    @user = {email_address: params.fetch(:email_address, '')}
  end

  def html_safe x
    x.html_safe
  end

  def create
    account_email = params.fetch(:user, {}).fetch(:email_address, nil)
    if account_email.blank?
      flash[:error] = I18n.t('users.reset-password.blank.html', sent_to: account_email, sign_up_path: new_user_path(email_address: account_email)).html_safe
      return redirect_to new_password_reset_path
    end

    @user = User.where(email_address: account_email).first
    if @user.nil?
      flash[:error] = I18n.t('users.reset-password.not-found.html', sent_to: account_email, sign_up_path: new_user_path(user: {email_address: account_email})).html_safe
      return redirect_to new_password_reset_path(email_address: account_email)
    end

    @user.deliver_password_reset_instructions!
    flash[:success] = I18n.t('users.reset-password.success.html', sent_to: @user.email_address).html_safe
    redirect_to new_user_session_path(email_address: @user.email_address)
  end

  def edit
    render
  end

  # Used solely when a user creates their profile and enters their password for the first time
  def update
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    if @user.save
      Notifier.welcome_email(@user.email_address).deliver
      update_password_flash_notice
      redirect_to user_path(@user.id)
    else
      render :action => :edit
    end
  end

  private

  def load_user_using_perishable_token
    @user = User.find_using_perishable_token(params[:id])
    unless @user
      flash[:notice] = "We're sorry, but we could not locate your account." +
        " If you are having issues try copying and pasting the URL " +
        "from your email into your browser or restarting the " +
        "reset password process."
      redirect_to new_user_session_path
    end
  end

  def update_password_flash_notice
    if @user.new_user? || @user.verified_email == false
      @user.update(verified_email: true)
      flash[:notice] = "Thank you. Your account has been verified. You may now contribute to H2O."
    else
      flash[:notice] = "Password successfully updated"
    end
  end
end
