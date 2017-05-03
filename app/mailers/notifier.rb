class Notifier < ActionMailer::Base
  default from: 'noreply@berkmancenter.org',
          sent_on: Proc.new { Time.now }

  def export_download_link(download_path, email_address)
    #NOTE: This makes some assumptions about where this app is mounted
    download_path = download_path.sub(/^#{Rails.root}\/public/, '')
    host = ActionMailer::Base.default_url_options[:host]
    port = ActionMailer::Base.default_url_options[:port]
    port = port.blank? ? '' : ":#{port}"

    # NOTE: Not a perfect heuristic
    if Rails.env.production? || port.to_s == '443'
      protocol = 'https'
    else
      protocol = 'http'
    end

    @download_url = "#{protocol}://#{host}#{port}#{download_path}"
    mail(to: email_address, subject: "Your H2O export is ready")
  end

  def case_notify_approved(case_obj, case_request)
    @case = case_obj
    mail(to: case_request.user.email_address, subject: "Case Request Approved")
  end

  def case_request_notify_rejected(case_request)
    @case_request = case_request
    mail(to: case_request.user.email_address, subject: "Case Request Not Accepted")
  end

  def password_reset_instructions(user)
    @token = user.perishable_token
    @edit_password_reset_url = edit_password_reset_url(user.perishable_token)
    mail(to: user.email_address, subject: "H2O Password Reset Instructions")
  end

  def verification_notice(user)
    mail(to: user.email_address, subject: "Welcome to H2O. Your account has been verified")
  end

  def admin_verification_request(user)
    @user = user
    @verification_url = rails_admin.edit_url(model_name: 'user', id: @user.id)
    mail(
      to: H2o::Application.config.user_verification_recipients,
      subject: "New H2O account needs verification"
    )
  end

  def logins(users)
    @new_password_reset_url = new_password_reset_url
    @users = users
    mail(to: users.map(&:email_address).uniq, subject: "H2O Logins")
  end

  def playlist_push_completed(user, playlist_name, new_playlist_id)
    @playlist_id = new_playlist_id
    mail(to: user.email_address, subject: "Push of Playlist #{playlist_name} completed")
  end

  def item_made_private(playlist, record)
    @playlist = playlist
    @record = record
    mail(to: playlist.user.email_address, subject: "Playlist Item Made Private")
  end

  def cases_list
    attachments['cases_list.csv'] = File.read("#{Rails.root}/tmp/cases_list.csv")
    mail(
      to: ['h2o@cyber.law.harvard.edu', 'awenner@cyber.law.harvard.edu', 'mmckay@law.harvard.edu'],
      subject: "List of All Cases #{Time.now.to_s(:simpledate)}"
    )
  end

  def bulk_upload_completed(user, bulk_upload)
    @bulk_upload = bulk_upload
    @bulk_upload_url = bulk_upload_url(bulk_upload)
    mail(to: user.email_address, subject: "Bulk Upload Completed")
  end

  def case_import_failure(user, case_metadata, options)
    @user = user 
    @case_metadata = case_metadata 
    @options = options
    mail(to: H2o::Application.config.admin_email, subject: 'Case import failed')
  end
end
