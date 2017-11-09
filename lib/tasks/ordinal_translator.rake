namespace :ordinal_translator do
  desc "Update Casebook ordinals to match Casebooks instead of Playlists"
  task :send => :environment do
    Content::Casebook.find_each do |casebook|
      id_map = PlaylistCasebookIdMap.build

      if casebook.ancestry.present?
        new_ancestry = []
        old_ancestry = casebook.ancestry.split("/")

        old_ancestry.each do |ancestry_node|
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
        casebook.update(ancestry: ancestry)
      end
    end
  end
end