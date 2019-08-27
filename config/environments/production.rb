H2o::Application.configure do
  # rails 5.1 configs:
  # Attempt to read encrypted secrets from `config/secrets.yml.enc`.
  # Requires an encryption key in `ENV["RAILS_MASTER_KEY"]` or
  # `config/secrets.yml.key`.
  config.read_encrypted_secrets = true
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'
  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

    config.action_controller.cache_store = :file_store, "tmp/cache/h2o/"
    config.cache_store = :file_store, "tmp/cache/h2o/"

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]
  config.log_level = :debug

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "h2o_#{Rails.env}"
  config.action_mailer.perform_caching = false

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # do not allow users without verified .edu addresses
  config.disable_verification = false

  # Old configs:
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like nginx, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable Rails's static asset server (Apache or nginx will already do this).
  # config.serve_static_assets = false

  # Compress JavaScripts and CSS.
  # config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  # config.assets.compile = false

  # Generate digests for assets URLs.
  # config.assets.digest = true

  # Version of your assets, change this if you want to expire all your assets.
  # config.assets.version = '1.0'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Set to :debug to see everything in the log.
  # config.log_level = :warn

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets.
  # application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
  # config.assets.precompile += %w( print.css export.js ui.css jquery.ui.custom.css )

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Disable automatic flushing of the log to improve performance.
  # config.autoflush_log = false

  config.action_mailer.default_url_options = { :host => ENV["MAILER_HOST"] }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV["SMTP_HOST"],
    authentication: :login,
    domain: ENV["MAILER_DOMAIN"],
    user_name: ENV["SMTP_USER"],
    password: ENV["SMTP_PW"],
    enable_starttls_auto: true,
    port: 587
  }

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  config.middleware.use ExceptionNotification::Rack,
    :ignore_exceptions => ['ActionController::BadRequest', 'ActionView::MissingTemplate'] + ExceptionNotifier.ignored_exceptions,
    :email => {
      :email_prefix => "[H2O] ",
      :sender_address => %Q{"H2O Exception" <#{ENV["EXCEPTION_EMAIL_SENDER"]}>},
      :exception_recipients => (ENV["EXCEPTION_RECIPIENTS"] || '').split(' ') + (ENV["CONTRACTOR_EMAIL_ADDRESSES"] || '').split(' ')
    }

  # Admin email to receive the 'new user needs verification' emails
  config.user_verification_recipients = (ENV["USER_VERIFICATION_RECIPIENTS"] || '').split(' ')

  config.admin_emails = (ENV["ADMIN_EMAIL"] || '').split(' ')
  config.professor_verifier_email = ENV["PROFESSOR_VERIFIER_EMAIL"]

  config.pandoc_export = ENV["RAILS_PANDOC_EXPORT"] == 'true'

end
