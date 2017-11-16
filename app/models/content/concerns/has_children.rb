# Concerns relevant to Content::Nodes that can contain children
module Content::Concerns::HasChildren
  extend ActiveSupport::Concern

  def children
    contents.where(['array_length(content_nodes.ordinals, 1) = ?', ordinals.length + 1])
  end

  def resources
    contents.where.not(resource_id: nil)
  end

  def can_delete?
    Rails.cache.fetch "content_section_is_empty_#{id}_#{updated_at.to_param}", expires_in: 24.hours do
      children.count == 0
    end
  end

  def present?
    true
  end

  def reflow_contents(child)
    @child = child
    reflow_tree(tree, ordinals)
  end

  def reflow_tree(tree, prefix = [])
    ord = 1
    tree.each do |element|
      if element.is_a? Enumerable
        element_prefix = ord == 1 ? prefix : prefix + [ord-1]
        reflow_tree(element, element_prefix)
      else
        unless element == @child && @child.destroyed?
          element.update_column :ordinals, prefix + [ord]
          ord += 1
        end
      end
    end
  end

  # Transform a flat sorted array of content into an array tree
  # [1, 1.1, 1.1.1, 1.2, 2, 2.1, 2.1.1] => [1, [1.1, [1.1.1], 1.2], 2, [2.1, [2.1.1]]]
  def tree
    tables = []
    table = []
    n_ords = ordinals.length + 1
    contents.each do |content|
      if content.ordinals.length > n_ords
        tables.push table.push(table = [])
      elsif content.ordinals.length < n_ords
        table = tables.pop until tables.length < content.ordinals.length
      end
      n_ords = content.ordinals.length
      table.push content
    end
    tables.first || table
  end
end
