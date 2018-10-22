source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem 'pg', '~> 0.21'
gem 'rails', '5.2.1'
gem 'puma', '~> 3.12'

gem 'webpacker'
gem 'jquery-rails'
gem 'jquery-ui-rails'

gem 'actionpack-page_caching'
gem 'acts-as-taggable-on', git: 'https://github.com/mbleigh/acts-as-taggable-on.git', ref: '9bb5738'
gem 'ancestry'
gem 'authlogic'
gem 'bcrypt'
gem 'cancancan'
gem 'capapi', git: 'https://github.com/leppert/capapi-ruby.git'
gem 'ckeditor', git: 'https://github.com/harvard-lil/ckeditor.git', branch: 'rails-5-1', ref: '8f6ff82'
gem 'coveralls', require: false
gem 'daemons', '1.0.10'
gem 'delayed_job_active_record'
gem 'delayed_job'
gem 'draper'
gem 'dropbox-sdk'
gem 'erubi'
gem 'erubis'
gem 'exception_notification'
gem 'exception_handler'
gem 'fastercsv'
gem 'formtastic'
gem 'hamlit'
gem 'high_voltage'
gem 'humanize'
gem 'http-cookie'
gem 'httparty'
gem 'jbuilder', '~> 2.6.3'
gem 'json', '1.8.6'
gem 'kaminari'
gem 'less-rails'
gem 'loofah', '~> 2.2.1'
gem 'loofah-activerecord', '~> 2.0.0'
gem 'nilify_blanks'
gem 'nokogiri', '~> 1.6'
gem 'paperclip', '~> 5.2.0'
gem 'progress_bar'
gem 'rails-observers'
gem 'rails_admin', '~> 1.3.0'
gem 'rails_admin_import'
gem 'rails-html-sanitizer'
gem 'RedCloth'
gem 'rest-client', '~> 1.8.0'
gem 'rubyzip'
gem 'sass-rails', '~> 5.0.6'
gem 'scrypt'
gem 'select2-rails'
gem 'simple_form'
gem 'sprockets-commoner'
gem 'sunspot_rails'
gem 'therubyracer', platforms: :ruby
gem 'uglifier', '>= 1.3.0'
gem 'warden'
gem 'will_paginate', git: 'https://github.com/asurin/will_paginate.git', ref:'9e1c0e0'

# export binary gems
gem 'htmltoword', require: true
gem 'methadone', require: false
gem 'wkhtmltopdf-binary', require: false

# Gems disabled for rails 5.1
# gem 'database_cleaner'
# gem 'capybara', '2.8' # compat with minitest-capybara
# gem 'minitest-rails-capybara'
# gem 'quiet_assets'


group :development do
  gem 'annotate'
  gem 'require_reloader'
  gem 'sunspot_solr'
  # gem 'web-console'

  gem 'guard'
  gem 'guard-bundler'
  gem 'guard-rails'
  gem 'guard-rake'
  gem 'guard-spring'
  gem 'guard-yield'
  gem 'guard-minitest'
  gem 'guard-sunspot', git: 'https://github.com/smit1625/guard-sunspot.git', ref: 'd7b24d8' # fork with Guard 2 support
  gem 'terminal-notifier-guard'
end

group :development, :test do
  gem 'dotenv-rails'
  gem 'launchy'
  gem 'minitest-metadata', require: false
  gem 'minitest-spec-rails'
  gem 'minitest-reporters'
  gem 'poltergeist'
  gem 'pry-byebug'
  gem 'simplecov'
  gem 'm'
  gem 'selenium-webdriver'

  gem 'wrong', git: 'https://github.com/pludoni/wrong.git', ref: 'be1ddcc' # fork with Rails 4 support
end

group :test do
  gem 'webmock'
end
