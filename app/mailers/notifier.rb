class Notifier < ActionMailer::Base
  default from: 'noreply@opencasebook.org',
          sent_on: Proc.new { Time.now }

  def password_reset_instructions(user)
    @token = user.perishable_token
    @edit_password_reset_url = edit_password_reset_url(user.perishable_token)
    mail(to: user.email_address, subject: "H2O Password Reset Instructions")
  end

  def verification_request(user)
    @verification_url = edit_password_reset_url(user.perishable_token)
    @user_name = user.display_name
    mail(to: user.email_address, subject: "An H2O account has been created for you")
  end

  def welcome_email(email_address)
    mail(to: email_address, subject: "Welcome to H2O!")
  end

  def professor_verification(user)
    @user = user
    @admin_url = rails_admin.edit_url(model_name: 'user', id: @user.id)
    mail(to: H2o::Application.config.professor_verifier_email, subject: "H2O Professor Verification Request for #{@user.display_name}")
  end

  def object_failure(user, object)
    @user = user
    @object = object
    mail(to: H2o::Application.config.admin_emails, subject: "Object failed to be saved or destroyed for #{@user.display_name}")
  end

  def merge_failed(user, draft, published, exception, exception_backtrace)
    @user = user
    @draft = draft
    @published = published
    @exception = exception
    @exception_backtrace = exception_backtrace
    mail(to: H2o::Application.config.admin_emails, subject: "Draft casebook merge in published failed #{@user.display_name}")
  end

  def missing_annotations(owners, resource, annotation)
    @owners = owners
    @resource = resource
    @annotation = annotation
    mail(to: H2o::Application.config.admin_emails, subject: "Missing annotations for paragraph nodes")
  end
end
