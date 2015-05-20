module IframeHelper
  def data_for(object)
    {
      external: url_for(object),
      type: object.class.to_s.downcase.pluralize
    }.tap do |data|
      if object.is_a?(Collage)
        extras = {
          layer_data: object.layer_data,
          highlights_only: object.highlights_only,
          raw_annotations: raw_annotations_for(object),
          editability_path: access_level_collage_path(object, iframe: true),
          original_data: object.readable_state || {},
          color_list: Collage.color_list
        }
        data.merge!(collage: extras)
      end
    end
  end
end
