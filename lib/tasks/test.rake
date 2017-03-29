namespace :test do
  desc "Run all tests and generate coverage report"
  task coverage: :environment do
    ENV['COVERAGE'] = 'true'
    Rake::Task["test"].invoke
  end
end
