namespace :ancestry_translator do
  desc "Update Casebook ordinals to match Casebooks instead of Playlists"
  task :translate => :environment do
    ## don't even need this anymore because am saving root owner id directly

    # only the primary playlists, not the ancestry playlists that were imported over - we don't care if those ancestrys are functional. 
    # playlist_ids = [66, 603, 633, 711, 986, 1324, 1324, 1369, 1510, 1844, 1844, 1862, 1889, 1923, 1923, 1995, 3762, 3762, 5094, 5143, 5555, 5555, 5804, 5866, 5876, 7072, 7337, 7337, 7384, 7390, 7399, 7446, 7446, 8624, 8770, 8770, 9141, 9156, 9157, 9267, 9267, 9364, 9504, 9623, 10007, 10007, 10033, 10065, 10236, 10237, 10572, 10609, 11114, 11114, 11492, 11800, 12489, 12716, 12826, 12864, 12865, 12922, 13023, 13034, 13086, 14454, 17803, 19763, 20336, 20370, 20406, 20443, 20493, 20630, 20630, 20861, 21225, 21225, 21529, 21529, 21898, 21913, 22180, 22188, 22189, 22235, 22269, 22363, 22368, 22568, 24353, 24419, 24704, 24739, 24739, 25022, 25421, 25606, 25698, 25965, 26039, 26057, 26074, 26143, 26147, 26147, 26147, 26221, 26221, 26241, 26271, 26372, 26401, 26452, 26559, 27297, 27438, 27790, 27819, 27845, 28015, 28148, 28286, 50966, 51028, 51291, 51531, 51575, 51676, 51703, 51759, 51760, 51770, 51792, 51938, 51938, 51971, 52383, 52511, 52719]
    # casebooks = Content::Casebook.where(playlist_id: playlist_ids)
    # id_map = {}

    # Content::Casebook.find_each do |casebook|
    #   id_map[casebook.playlist_id] = casebook.id
    # end

    # casebooks.find_each do |casebook|
    #   if casebook.ancestry.present?
    #     new_ancestry = []
    #     old_ancestry = casebook.ancestry.split("/")
    #     puts "casebook id #{casebook.id}"
    #     puts "old ancestry: #{old_ancestry}"

    #     old_ancestry.each do |ancestry_node|
    #       ancestry_node = ancestry_node.to_i

    #       if ancestry_node == 12622
    #         new_ancestry << 12922
    #       elsif ancestry_node == 12668
    #         new_ancestry << 12826
    #       else
    #         ## this needs to fail or a better error message
    #         casebook_id = id_map[ancestry_node]
    #         new_ancestry << casebook_id
    #       end
    #     end

    #     ancestry = new_ancestry.join("/")
    #     puts "new ancestry #{ancestry}"
    #     # casebook.update(ancestry: ancestry)
    #   end
    # end
  end
end