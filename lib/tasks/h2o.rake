namespace :h2o do
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
