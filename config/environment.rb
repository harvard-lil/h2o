# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.18' unless defined? RAILS_GEM_VERSION

#ENV['RAILS_ENV'] = 'production'

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  # Add additional load paths for your own custom dirs
  config.autoload_paths += %W( #{RAILS_ROOT}/app/sweepers)

  # Specify gems that this application depends on and have them installed with rake gems:install
  config.gem "authlogic", :version => '2.1.3'
  config.gem "oauth", :version => '0.3.6'
  config.gem "authlogic-oauth", :lib => "authlogic_oauth", :version => '1.0.8'
  config.gem "acl9", :version => '0.12.0'
  config.gem "shoulda", :version => '2.10.3'
  config.gem 'factory_girl', :version => '2.6.4'
  config.gem "formtastic", :version => '1.1.0'
  config.gem "RedCloth", :version => '4.2.2'
  config.gem 'acts-as-taggable-on', :version => '2.0.6'
  config.gem 'fastercsv', :version => '1.5.3'
  config.gem 'ancestry', :version => '1.2.0'
  config.gem 'will_paginate', :version => '2.3.14'
  config.gem 'tidy_ffi', :version => '0.1.3'
  config.gem 'sunspot', :lib => 'sunspot', :version => '1.1.0'
  config.gem 'super_exception_notifier', :lib => "exception_notification", :version => '3.0.13'
  #erubis is needed to satisfy requirements for rails_xss plugin
  config.gem 'erubis', :version => '2.6.6'
  config.gem 'daemons', :version => '1.0.10'
  config.gem "delayed_job", :version => "2.0.4"
  config.gem 'nokogiri', :version => '1.4.1'
  config.gem 'starling'
  config.gem 'rdoc'

  #2013.09.23 Removed b/c appears to be unused:
  #config.gem 'youtube-g', :version => '0.5.0', :lib => 'youtube_g'
  #config.gem "ar-extensions", :version => "0.9.5"
  #config.gem "authlogic_facebook", :version => '1.0.4'
  #config.gem "vote_fu", :version => '0.0.11'
 
  #special configuration
  #config.gem 'sunspot_rails', :lib => 'sunspot/rails', :version => '1.1.0'
  #config.gem 'dropbox-sdk', :version => '1.5.1'

  config.active_record.colorize_logging = false

  # set log rotation
  config.logger = Logger.new(config.log_path, 25, 2097152)

  # Only load the plugins named here, in the order given (default is alphabetical).
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Skip frameworks you're not going to use. To use Rails without a database,
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

  # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
  # Run "rake -D time" for a list of tasks for finding time zone names.
  config.time_zone = 'UTC'

  # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
  # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
  # config.i18n.default_locale = :de

  config.after_initialize do
    Workling::Remote.dispatcher = Workling::Remote::Runners::StarlingRunner.new
  end

end

Mime::Type.register "application/pdf", :pdf
