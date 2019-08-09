class AddGlobalOffsetsToAnnotations < ActiveRecord::Migration[5.2]
  ANNOTATABLES = [Case, TextBlock]

  def up
    add_column :content_annotations, :global_start_offset, :integer
    add_column :content_annotations, :global_end_offset, :integer

    ANNOTATABLES.each do |klass|
      # Calculate global annotation offsets using the version of HTMLUtils
      # sanitization in place at the time the annotation was created.
      klass.annotated.find_each do |instance|
        # cache these to reduce DB access and parsing time
        utils = nil
        breakpoints = nil

        instance.annotations.order(created_at: :asc).find_each do |a|
          # invalidate cached items if needed
          date = [a.created_at, HTMLUtils::V3::EFFECTIVE_DATE].min
          new_utils = HTMLUtils.at(date)
          if new_utils != utils
            utils = new_utils
            nodes = HTMLUtils.parse(utils.cleanse(instance.raw_content.content)).at('body').children
            breakpoints = AnnotationConverter.nodes_to_breakpoints(nodes)
          end
          # use update_columns to avoid touching the timestamps
          a.update_columns [:start, :end].map { |position|
            ["global_#{position}_offset",
             a["#{position}_offset"] + breakpoints[[a["#{position}_paragraph"], breakpoints.length - 1].min]]
          }.to_h
        end
      end
    end
  end

  def down
    remove_column :content_annotations, :global_start_offset
    remove_column :content_annotations, :global_end_offset
  end
end
