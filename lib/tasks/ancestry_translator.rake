namespace :ancestry_translator do
  desc "Update Casebook ordinals to match Casebooks instead of Playlists"
  task :translate => :environment do
    Content::Casebook.find_each do |casebook|
      id_map = {}

      Content::Casebook.find_each do |casebook|
        id_map[casebook.playlist_id] = casebook.id
      end

      if casebook.ancestry.present?
        new_ancestry = []
        old_ancestry = casebook.ancestry.split("/")
        puts "casebook id #{casebook.id}"
        puts "old ancestry: #{old_ancestry}"

        old_ancestry.each do |ancestry_node|
          ancestry_node = ancestry_node.to_i

          if ancestry_node == 12622
            new_ancestry << 12922
          elsif ancestry_node == 12668
            new_ancestry << 12826
          else
            casebook_id = id_map[ancestry_node]
            new_ancestry << casebook_id
          end
        end
       
        ancestry = new_ancestry.join("/")
        puts "new ancestry #{ancestry}"
        casebook.update(ancestry: ancestry)
      end
    end
  end
end