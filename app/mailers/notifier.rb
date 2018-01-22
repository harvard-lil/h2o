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
    @user_name = user.attribution
    @user_affiliation = user.affiliation
    @user_email_address = user.email_address
    mail(to: 'bjohnson@law.harvard.edu', subject: "H2O Professor Verification Request for #{user.attribution}")
    user.update(professor_verification_sent: true)
  end
end
