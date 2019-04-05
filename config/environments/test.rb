H2o::Application.configure do
  # rails 5.1 configs:
  config.action_mailer.perform_caching = false
  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.seconds.to_i}"
  }
  config.cache_store = :memory_store

  config.active_job.queue_adapter = :test

  # config.action_view.raise_on_missing_translations = true

  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false 

  # Configure static asset server for tests with Cache-Control for performance.
  # config.serve_static_assets  = true
  # config.assets.debug = true
  # config.static_cache_control = "public, max-age=3600"

  # do not allow unverified users
  config.disable_verification = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  config.admin_email = ['cgruppioni@law.harvard.edu']
  config.professor_verifier_email = "cgruppioni@law.harvard.edu"
end
