source 'https://rubygems.org'

gem 'pg'
gem 'rails', '5.1.0.rc1'
gem 'puma', '~> 3.8'

# Gems disabled for rails 5.1
# gem 'coffee-rails', '~> 4.0.0'
# gem 'jquery-rails'
# gem 'jquery-ui-rails'
# gem 'rails-observers'
# gem 'rails_admin_import', '0.1.9'
# gem 'rails_admin'

gem 'actionpack-page_caching'
gem 'acts-as-taggable-on', '~> 4.0.0' # Note: 3.2.1. has a bug that causes chain of UPDATE/DELETEs on annotations tagged when required tag removed
gem 'ancestry'
gem 'authlogic'
gem 'bcrypt'
gem 'cancan'
gem 'ckeditor'
gem 'coveralls', require: false
gem 'daemons', '1.0.10'
gem 'delayed_job_active_record'
gem 'delayed_job'
gem 'dropbox-sdk'
gem 'exception_notification'
gem 'fastercsv'
gem 'formtastic', '~> 2.3.0.rc2'
gem 'jbuilder', '~> 1.2'
gem 'json', '1.8.6'
gem 'kaminari'
gem 'loofah-activerecord', '~> 1.2'
gem 'nokogiri', '~> 1.6'
gem 'paperclip'
gem 'progress_bar'
gem 'RedCloth'
gem 'sass-rails', '~> 5.0.6'
gem 'scrypt'
gem 'sunspot_rails'
gem 'therubyracer', platforms: :ruby
gem 'uglifier', '>= 1.3.0'
gem 'warden'
gem 'will_paginate'


# Gems disabled for rails 5.1
# gem 'database_cleaner'
# gem 'capybara', '2.8' # compat with minitest-capybara
# gem 'minitest-rails-capybara'
# gem 'minitest-rails'
# gem 'quiet_assets'

group :development do
  gem 'annotate'
  gem 'sunspot_solr'
  gem 'web-console'

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
  gem 'launchy'
  gem 'minitest-reporters'
  gem 'poltergeist'
  gem 'pry-byebug'
  gem 'simplecov'
  gem 'm'

  gem 'wrong', git: 'https://github.com/pludoni/wrong.git', ref: 'be1ddcc' # fork with Rails 4 support
end
