namespace :h2o do
  desc 'Clear Page Caches'
  task(:clear_page_cache => :environment) do
    system("mv #{Rails.root}/public/collages #{Rails.root}/public/collages.delete && mkdir #{Rails.root}/public/collages && rm -rf #{Rails.root}/public/collages.delete")
    system("mv #{Rails.root}/public/playlists #{Rails.root}/public/playlists.delete && mkdir #{Rails.root}/public/playlists && rm -rf #{Rails.root}/public/playlists.delete")
    system("mv #{Rails.root}/public/cases #{Rails.root}/public/cases.delete && mkdir #{Rails.root}/public/cases && rm -rf #{Rails.root}/public/cases.delete")
    system("mv #{Rails.root}/public/p #{Rails.root}/public/p.delete && mkdir #{Rails.root}/public/p && rm -rf #{Rails.root}/public/p.delete")
    system("rm #{Rails.root}/public/index.html")
    system("mv #{Rails.root}/public/iframe #{Rails.root}/public/iframe.delete && mkdir #{Rails.root}/public/iframe && rm -rf #{Rails.root}/public/iframe.delete")
    system("mv #{Rails.root}/public/svg_icons #{Rails.root}/public/svg_icons.delete && mkdir #{Rails.root}/public/svg_icons && rm -rf #{Rails.root}/public/svg_icons.delete")
  end
  
  desc 'Clear Homepage Cache'
  task(:clear_homepage_cache => :environment) do
    system("rm #{Rails.root}/public/index.html")
  end
  
  desc 'Clear All Cache'
  task(:clear_all_cache => :environment) do
    system("mv #{Rails.root}/tmp/cache/h2o #{Rails.root}/tmp/cache/h2o.delete && mkdir #{Rails.root}/tmp/cache/h2o && rm -rf #{Rails.root}/tmp/cache/h2o.delete")
    Rake::Task["h2o:clear_page_cache"].execute
  end

  desc 'Send cases list email'
  task(:send_cases_list_email => :environment) do
    body = Case.all.collect { |c| c.to_tsv }.join("\n")
    File.open("#{Rails.root}/tmp/cases_list.csv", 'w') { |file| file.write(body) }
    Notifier.cases_list.deliver
  end
end
