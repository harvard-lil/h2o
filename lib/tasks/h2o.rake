namespace :h2o do
  desc 'Clear Page Caches'
  task(:clear_page_cache => :environment) do
    dirs = %w[/public/collages /public/playlists /public/cases /public/p /public/iframe /public/svg_icons]
    dirs.each do |dir|
      puts "Moving #{dir} to #{dir}.delete"
      system "mv #{Rails.root}#{dir} #{Rails.root}#{dir}.delete && mkdir #{Rails.root}#{dir}"
    end

    Rake::Task["h2o:clear_homepage_cache"].execute

    dirs.each do |dir|
      delete_dir = "#{dir}.delete"
      puts "Deleting #{delete_dir}"
      system "rm -rf #{Rails.root}#{delete_dir}"
    end
  end

  desc 'Clear Homepage Cache'
  task(:clear_homepage_cache => :environment) do
    system("rm #{Rails.root}/public/index.html")
  end

  desc 'Clear All Cache'
  task(:clear_all_cache => :environment) do
    dir = "/tmp/cache/h2o"
    puts "Moving #{Rails.root}#{dir} to #{Rails.root}#{dir}.delete"
    system("mv #{Rails.root}#{dir} #{Rails.root}#{dir}.delete && mkdir #{Rails.root}#{dir}")

    Rake::Task["h2o:clear_page_cache"].execute

    puts "Deleting #{dir}.delete (this may take a while)"
    system("rm -rf #{Rails.root}#{dir}.delete")
  end

  desc 'Migrate All Playlists'
  task(:migrate_playlists => :environment) do
    Migrate.migrate_all_playlists
    puts 'Done!'
  end
end
