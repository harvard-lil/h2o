# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

H2o::Application.load_tasks

Rake::Task['yarn:install'].clear
namespace :yarn do
  desc "Override yarn:install. Don't do anything!"
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
