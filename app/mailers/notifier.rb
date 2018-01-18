class Notifier < ActionMailer::Base
  default from: 'noreply@opencasebook.org',
          sent_on: Proc.new { Time.now }

  def password_reset_instructions(user)
    @token = user.perishable_token
    @edit_password_reset_url = edit_password_reset_url(user.perishable_token)
    mail(to: user.email_address, subject: "H2O Password Reset Instructions")
  end

  def verification_request(user)
    @verification_url = verify_user_url(user, token: user.perishable_token)
    @user_name = user.display_name
    mail(to: user.email_address, subject: "H2O: Verify your email address")
  end

  def verification_notice(user)
    mail(to: user.email_address, subject: "Welcome to H2O. Your account has been verified")
  end

  def professor_verification(user)
    @user = user
    @admin_url = rails_admin.edit_url(model_name: 'user', id: @user.id)
    mail(to: H2o::Application.config.professor_verification_email, subject: "H2O Professor Verification Request for #{@user.display_name}")
    @user.update(professor_verification_requested: true)
  end
end
