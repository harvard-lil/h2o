require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)


module H2o
  class Application < Rails::Application
    # upgrade to 5.1:
    config.load_defaults 5.1

    # Rails.env = ActiveSupport::StringInquirer.new('production')
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.autoload_paths += %W(#{config.root}/lib)
    config.action_controller.page_cache_directory = "#{Rails.root}/public"

    config.action_controller.cache_store = :file_store, "tmp/cache/h2o/"
    config.cache_store = :file_store, "tmp/cache/h2o/"
    # config.skylight.environments << 'development'
  end
end
