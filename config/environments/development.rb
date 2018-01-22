H2o::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # rails 5 configs:
  # config.action_controller.perform_caching = false
  # config.cache_store = :null_store
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store, { size: 64.megabytes }

  config.action_mailer.perform_caching = false
  config.assets.quiet = true
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

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = false

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

  config.admin_email = 'cgruppioni@law.harvard.edu'
  config.cap_api_key = '2c62c54b47e507b2eee20a70f29f1b4ae0ccd1a3'

end
