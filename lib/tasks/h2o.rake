namespace :h2o do
  desc 'Clear Page Caches'
  task(:clear_page_cache => :environment) do
    system("rm -rf #{Rails.root}/public/collages/*")
    system("rm -rf #{Rails.root}/public/playlists/*")
    system("rm -rf #{Rails.root}/public/cases/*")
    system("rm -rf #{Rails.root}/public/p/*")
    system("rm -rf #{Rails.root}/public/index.html")
  end
  
  desc 'Clear Homepage Cache'
  task(:clear_homepage_cache => :environment) do
    system("rm -rf #{Rails.root}/public/index.html")
  end
  
  desc 'Clear All Cache'
  task(:clear_all_cache => :environment) do
    system("rm -rf #{Rails.root}/tmp/cache/h2o/*")
    Rake::Task["h2o:clear_page_cache"].execute
  end

  desc 'Send cases list email'
  task(:send_cases_list_email => :environment) do
    body = Case.all.collect { |c| c.to_tsv }.join("\n")
    File.open("#{Rails.root}/tmp/cases_list.csv", 'w') { |file| file.write(body) }
    Notifier.cases_list.deliver
  end
end
