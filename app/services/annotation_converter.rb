class AnnotationConverter
  class << self
    def paragraph_nodes_to_breakpoints(paragraph_nodes)
      paragraph_nodes.reduce([0]) {
        |lens, node| lens << lens[lens.length - 1] + node.text.gsub("\r\n", "\n").length
      }
    end

    def global_offsets_to_paragraph_offsets(paragraph_nodes, start_offset, end_offset)
      breakpoints = paragraph_nodes_to_breakpoints(paragraph_nodes)
      start_paragraph = breakpoints.find_index { |i| i > start_offset } - 1
      end_paragraph = breakpoints.find_index { |i| i >= end_offset } - 1

      {
        start_paragraph: start_paragraph,
        end_paragraph: end_paragraph,
        start_offset: start_offset - breakpoints[start_paragraph],
        end_offset: end_offset - breakpoints[end_paragraph]
      }
    end
  end
end
