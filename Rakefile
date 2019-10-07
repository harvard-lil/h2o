# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

H2o::Application.load_tasks

Rake::Task['yarn:install'].clear
namespace :yarn do
  desc "Overridden yarn:install. Don't do anything!"
  task :install => [:environment] do
    puts "Skipping yarn:install"
  end
end

Rake::Task['webpacker:yarn_install'].clear
namespace :webpacker do
  desc "Overridden webpacker:yarn_install. Don't do anything!"
  task :yarn_install => [:environment] do
    puts "Skipping webpacker:yarn_install"
  end
end

# Alphabetize columns when producing schema.rb, to make diffs/comparisons easier
# Technique from https://www.pgrs.net/2008/03/12/alphabetize-schema-rb-columns/
task :'db:schema:dump' => :'db:alphabetize_columns'
task :'db:alphabetize_columns' do
  class << ActiveRecord::Base.connection
    alias_method :old_columns, :columns unless self.instance_methods.include?("old_columns")

    def columns(*args)
      old_columns(*args).sort_by(&:name)
    end
  end
end
