class UpdateBooleanAttributes < ActiveRecord::Migration
  def self.up
    #so - at least under postgres - adding a boolean column with a default DOES NOT actually 
    # cause that default to be applied to existing rows. boo hoo.

    ['annotations','cases','collages','item_annotations','item_cases','item_collages','item_defaults','item_playlists','item_questions','item_question_instances','item_rotisserie_discussions','item_texts','item_youtubes','playlist_items','playlists','question_instances','questions','rotisserie_discussions','rotisserie_posts','rotisserie_instances'].each do|t|
      execute "update #{t} set active = true where active is null"
      execute "update #{t} set public = true where active is null"
    end
  end

  def self.down
  end
end
