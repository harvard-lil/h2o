class AddGlobalOffsetsToAnnotations < ActiveRecord::Migration[5.2]
  ANNOTATABLES = [Case, TextBlock]

  def up
    add_column :content_annotations, :global_start_offset, :integer
    add_column :content_annotations, :global_end_offset, :integer

    ANNOTATABLES.each do |klass|
      klass.annotated.find_each do |instance|
        nodes = Nokogiri::HTML(instance.content).xpath("//body/node()[not(self::text())]")
        breakpoints = AnnotationConverter.nodes_to_breakpoints(nodes)
        instance.annotations.find_each do |a|
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
