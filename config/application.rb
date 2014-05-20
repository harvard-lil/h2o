require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module H2o
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.autoload_paths += %W(#{config.root}/lib #{config.root}/lib/core_ext #{config.root}/lib/dropbox)
    config.action_controller.page_cache_directory = "#{Rails.root.to_s}/public"

    config.middleware.use ExceptionNotification::Rack,
      :email => {
        :email_prefix => "[H2O] ",
        :sender_address => %{"H2O Exception" <h2o+errors@cyber.law.harvard.edu>},
        :exception_recipients => %w{steph@endpoint.com} #later add h2o@cyber.law.harvard.edu tim@endpoint.com
      }
  end
end
