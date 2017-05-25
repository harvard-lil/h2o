class AutoClone < ActiveRecord::Migration
  def up
    conxn = ActiveRecord::Base.connection
    conxn.execute "UPDATE playlist_items SET name = REGEXP_REPLACE(name, '\s+', '') WHERe name LIKE ' %'"

    [Media, Default, TextBlock, Collage].each do |klass|
      table_name = klass == Media ? "medias" : klass.to_s.tableize
      conxn.execute "UPDATE #{table_name} SET name = REGEXP_REPLACE(name, '\s+', '') WHERE name LIKE ' %'"
      results = conxn.select_rows("SELECT pi.id FROM playlist_items pi
        JOIN #{table_name} m ON m.id = pi.actual_object_id
        WHERE pi.actual_object_type = '#{klass.to_s}'
          AND (pi.name != m.name OR
               (COALESCE(pi.description, '') != '' AND COALESCE(pi.description, '') != m.description)
              )")
      if klass == Collage
        results = conxn.select_rows("SELECT pi.id FROM playlist_items pi
          JOIN #{table_name} m ON m.id = pi.actual_object_id
          WHERE pi.actual_object_type = '#{klass.to_s}'
            AND (pi.name != m.name OR pi.description != m.description)")
      end
      PlaylistItem.where(id: results.flatten).find_in_batches do |set|
        set.each do |playlist_item|
          updated_params = {}
          updated_params[:name] = playlist_item.attributes["name"] if playlist_item.attributes["name"] != playlist_item.name
          updated_params[:description] = playlist_item.attributes["description"] if playlist_item.attributes["description"] != playlist_item.description && playlist_item.attributes["description"] != ""

          next if updated_params.empty?
          if playlist_item.playlist.user == playlist_item.actual_object.user
            playlist_item.actual_object.update_columns(updated_params)
          else
            new_item = playlist_item.actual_object.h2o_clone(playlist_item.playlist.user, updated_params)
            new_item.save(validate: false)
            playlist_item.update_attributes({ :actual_object_id => new_item.id })
          end
        end
      end
    end

    case_results = conxn.select_rows("SELECT pi.id, pi.name, pi.description, m.short_name FROM playlist_items pi JOIN cases m ON m.id = pi.actual_object_id WHERE pi.actual_object_type = 'Case' AND (pi.name != m.short_name OR COALESCE(pi.description, '') != '')")
    PlaylistItem.where(id: case_results.flatten).find_in_batches do |set|
      set.each do |playlist_item|
        playlist_item.update_columns({ :notes => playlist_item.description })
      end
    end

    remove_column :playlist_items, :description
    remove_column :playlist_items, :name
  end

  def down
    # Nothing
  end
end
