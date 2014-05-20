class LoginNotifiersController < ApplicationController
  def new
  end
  
  def create    
    @users = User.where(email_address: params[:email_address])
    if @users.size > 0 
      Notifier.logins(@users).deliver

      flash[:notice] = "Logins associated with this email address were sent. " +
        "Please check your email."
      redirect_to new_password_reset_path
    else
      flash[:notice] = "No logins were found with that email address"
      render :action => :new
    end    
  end
end
