ExceptionNotification::Notifier.configure_exception_notifier do |config|
  config[:app_name]                 = "[H2O-Rails]"
  config[:sender_address]           = "h2o+errors@cyber.law.harvard.edu"
  config[:exception_recipients]     = ['djcp+errors@cyber.law.harvard.edu']

  # In a local environment only use this gem to render, never email
  #defaults to false - meaning by default it sends email.  Setting true will cause it to only render the error pages, and NOT email.
  config[:skip_local_notification]  = false

  # Error Notification will be sent if the HTTP response code for the error matches one of the following error codes
  config[:notify_error_codes]   = %W( 405 500 503 )

  # Error Notification will be sent if the error class matches one of the following error classes
  config[:notify_error_classes] = %W( )

  # What should we do for errors not listed?
  config[:notify_other_errors]  = false

  # If you set this SEN will attempt to use git blame to discover the person who made the last change to the problem code
  config[:git_repo_path]            = nil # ssh://git@blah.example.com/repo/webapp.git
end

