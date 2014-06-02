namespace :h2o do
  desc 'Update item karma'
  task(:update_user_karma => :environment) do
    Rails.cache.delete_matched(%r{user-barcode-*})
    User.find_in_batches(:batch_size => 20) do |items|
      items.each do |i|
        i.update_karma
      end
    end
  end

  desc 'Clear Static Page Caches'
  task(:clear_static_page_cache => :environment) do
    system("rm -rf #{Rails.root}/public/p/*")
  end
  
  desc 'Clear Page Caches'
  task(:clear_page_cache => :environment) do
    system("rm -rf #{Rails.root}/public/collages/*")
    system("rm -rf #{Rails.root}/public/playlists/*")
    system("rm -rf #{Rails.root}/public/cases/*")
  end
  
  desc 'Clear UI Caches'
  task(:clear_ui_cache => :environment) do
    system("rm -rf #{Rails.root}/public/stylesheets/all.css")
    system("rm -rf #{Rails.root}/public/javascripts/all.js")
  end

  desc 'Clear Homepage Cache'
  task(:clear_homepage_cache => :environment) do
    system("rm -rf #{Rails.root}/public/index.html")
  end
  
  desc 'Clear All Cache'
  task(:clear_all_cache => :environment) do
    system("rm -rf #{Rails.root}/tmp/cache/*")
    Rake::Task["h2o:clear_ui_cache"].execute
    Rake::Task["h2o:clear_page_cache"].execute
    Rake::Task["h2o:clear_homepage_cache"].execute
    Rake::Task["h2o:clear_static_page_cache"].execute
  end

  desc 'Send cases list email'
  task(:send_cases_list_email => :environment) do
    body = Case.all.collect { |c| c.to_tsv }.join("\n")
    File.open("#{Rails.root}/tmp/cases_list.csv", 'w') { |file| file.write(body) }
    Notifier.cases_list.deliver
  end

  desc 'Upgrade collages'
  task(:upgrade_collages => :environment) do
    Collage.find_each(batch_size: 10) do |collage|
      if collage.annotator_version == 1
        collage.upgrade_via_nokogiri
        puts "updated #{collage.id}"
      end
    end
  end
end
