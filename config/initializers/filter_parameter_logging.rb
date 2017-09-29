# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [:password, :password_confirmation, :session, :warden, :secret, :salt, :cookie, :csrf, :api_key, :pw, :secret]
