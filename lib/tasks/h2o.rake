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

  desc 'Correlate H2O Cases to CAPAPI Cases'
  task(:correlate_cases => :environment) do
    query = Case.where(capapi_id: nil)
    total = query.count
    count = 0
    query.find_each do |c|
      count += 1
      if c.citations[0]
        capapi_case = Capapi::Case.list(cite: c.citations[0]["cite"]).first
        if capapi_case
          c.update(capapi: capapi_case)
          puts "#{count}/#{total}",
               "H2O:    #{c.name}",
               "CAPAPI: #{capapi_case.name}",
               ""
        end
      end
    end
    puts 'Done!'
  end
end
