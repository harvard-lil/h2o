# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  # Add additional load paths for your own custom dirs
  config.load_paths += %W( #{RAILS_ROOT}/app/sweepers )

  # Specify gems that this application depends on and have them installed with rake gems:install
  # config.gem "bj"
  # config.gem "sqlite3-ruby", :lib => "sqlite3"
  # config.gem "aws-s3", :lib => "aws/s3"

  config.gem "authlogic", :version => '2.1.3', :source => "http://gemcutter.org"
  config.gem "oauth", :version => '0.3.6', :source => "http://gemcutter.org"
  config.gem "authlogic-oauth", :lib => "authlogic_oauth", :version => '1.0.8', :source => "http://gemcutter.org"
  config.gem "authlogic_facebook", :version => '1.0.4', :source => "http://gemcutter.org"
  config.gem "acl9", :version => '0.12.0', :source => "http://gemcutter.org"
  config.gem "shoulda", :version => '2.10.3', :source => "http://gemcutter.org"
  config.gem "formtastic", :version => '0.9.7', :source => "http://gemcutter.org"
  config.gem "vote_fu", :version => '0.0.11', :source => "http://gemcutter.org"
  config.gem "RedCloth", :version => '4.2.2'
  config.gem 'nokogiri', :version => '1.4.1'
  config.gem 'youtube-g', :version => '0.5.0', :lib => 'youtube_g'
  config.gem 'acts-as-taggable-on', :version => '2.0.6'

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

  config.action_mailer.default_url_options = { :host => 'localhost', :port => 3000 }

end


