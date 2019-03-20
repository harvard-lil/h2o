H2o::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # rails 5 configs:
  # config.action_controller.perform_caching = false
  # config.cache_store = :null_store
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store, { size: 64.megabytes }

  config.action_mailer.perform_caching = false
  
  # config.action_view.raise_on_missing_translations = true
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  # config.cache_classes = false

  # allow users without verified .edu addresses
  config.disable_verification = true

  # Do not eager load code on boot.
  config.eager_load = false

  config.assets.digest = false 
  # config.assets.compile = false
  config.assets.quiet = true
  config.assets.debug = true

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.action_mailer.delivery_method = :sendmail
  config.action_mailer.perform_deliveries = true
  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  #TODO: It's a little strange to have the port number embedded in the host
  #like that, but we don't have time to remove it and re-test everywhere.
  host = 'h2o-dev.local:8000'
  config.action_mailer.default_url_options = { :host => host }

  config.middleware.use ExceptionNotification::Rack,
    :ignore_exceptions => ['ActionController::BadRequest'] + ExceptionNotifier.ignored_exceptions,
    :email => {
      :email_prefix => "[H2Odev] ",
      :sender_address => %{"H2O Exception" <h2o+errors@cyber.law.harvard.edu>},
      :exception_recipients => %w{}
    }

  # Admin email to recieve the 'new user needs verification' emails
  config.user_verification_recipients = ['cgruppioni@law.harvard.edu']

  config.admin_emails = ['cgruppioni@law.harvard.edu']
  config.professor_verifier_email = "cgruppioni@law.harvard.edu"

  if ENV['DOCKERIZED'].present?
    # Web Console launches an interactive debugging console in your browser.
    # If running in Docker, requests don't come from localhost, so we have to
    # whitelist the whole private network.
    # https://github.com/rails/web-console#configweb_consolewhitelisted_ips
    config.web_console.whitelisted_ips = '192.168.0.0/16'
  end
end
