puts "Importing seed data:"

%w{base users defaults textblocks cases casebooks contents collaborators}.each do |model|
	puts "Seeding #{model}..."
	load "seeds/#{model}.rb"
