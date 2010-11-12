# Require the plugin code
require 'localized_language_select'

# Load locales for languages from +locale+ directory into Rails
I18n.load_path += Dir[ File.join(File.dirname(__FILE__), 'locale', '*.{rb,yml}') ]
