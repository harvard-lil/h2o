class AnnotationConverter
  class << self
    def nodes_to_breakpoints(nodes)
      nodes.reduce([0]) {
        |breakpoints, node| breakpoints << breakpoints[breakpoints.length - 1] + self.get_node_length(node)
      }
    end

    def global_offsets_to_node_offsets(nodes, start_offset, end_offset)
      breakpoints = nodes_to_breakpoints(nodes)
      start_paragraph = breakpoints.find_index { |i| i > start_offset } - 1
      end_paragraph = breakpoints.find_index { |i| i >= end_offset } - 1

      {
        start_paragraph: start_paragraph,
        end_paragraph: end_paragraph,
        start_offset: start_offset - breakpoints[start_paragraph],
        end_offset: end_offset - breakpoints[end_paragraph]
      }
    end

    def get_node_text(node)
      node.text.gsub("\r\n", "\n")
    end

    def get_node_length(node)
      get_node_text(node).length
    end
  end
end
