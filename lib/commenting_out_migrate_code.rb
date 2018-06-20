def migrate_items(playlist_items, path:, casebook: )
      playlist_items.order(:position).each_with_index do |item, index|
        if item.actual_object_type.in? %w{Playlist Collage Media}
          item.actual_object_type = "Migrate::#{item.actual_object_type}"
        end
        object = item.actual_object
        ordinals = path + [index + 1]
        if object.is_a? Migrate::Playlist
          # Content::Section.create casebook: casebook,
          #   title: object.name,
          #   headnote: sanitize(object.description),
          #   ordinals: ordinals
          migrate_items object.playlist_items, path: ordinals, casebook: casebook
        else
          imported_resource = object

          # if imported_resource.nil?
          #   imported_resource = Default.create name: "[Missing #{item.actual_object_type} \##{item.actual_object_id}]",
          #     url: "https://h2o.law.harvard.edu/#{item.actual_object_type.downcase}s/#{item.actual_object_id}"
          # end

          if imported_resource.is_a? Migrate::Collage
            if imported_resource.annotatable_type.in? %w{Playlist Collage Media}
              imported_resource.annotatable_type = "Migrate::#{object.annotatable_type}"
            end
            # if imported_resource.description.present? && item.notes.present?
            #   case_headnote = sanitize(imported_resource.description) + " " + sanitize(item.notes)
            # elsif imported_resource.description.present?
            #   case_headnote = sanitize(imported_resource.description)
            # else
            #   case_headnote = sanitize(item.notes)
            # end
            imported_resource = imported_resource.annotatable ## not sure if I need to be doing this ***

            # if imported_resource.nil?
            #   imported_resource = Default.create name: "[Missing annotated #{object.annotatable_type} \##{object.annotatable_id}]",
            #     url: "https://h2o.law.harvard.edu/collages/#{object_id}"
            # end
          end

          # if imported_resource.is_a? Migrate::Media
          #   imported_resource = Default.create name: imported_resource.name,
          #     description: imported_resource.description,
          #     url: imported_resource.content,
          #     user_id: imported_resource.user_id
          # end

          # resource = Content::Resource.create casebook: casebook,
          #   resource: imported_resource,
          #   ordinals: ordinals

          if object.is_a? Migrate::Collage
            migrate_annotations(object, resource)
            resource.headnote = case_headnote
            resource.save
          end
          resource
        end
      end
    end