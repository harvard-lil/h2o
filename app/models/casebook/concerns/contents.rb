module Casebook::Concerns::Contents
  extend ActiveSupport::Concern

  def children
    contents.where(['array_length(casebooks.ordinals, 1) = ?', ordinals.length + 1])
  end

  def resources
    contents.where.not(resource_id: nil)
  end

  def can_delete?
    children.count == 0
  end

  def present?
    true
  end

  def reflow_contents
    reflow_tree tree, ordinals
  end

  def reflow_tree tree, prefix = []
    ord = 1
    tree.each do |element|
      if element.is_a? Enumerable
        reflow_tree element, ord == 1 ? prefix : prefix + [ord-1]
      else
        element.update_column :ordinals, prefix + [ord]
        ord += 1
      end
    end
  end

  # Transform a flat sorted array of casebooks into an array tree
  # [1, 1.1, 1.1.1, 1.2, 2, 2.1, 2.1.1] => [1, [1.1, [1.1.1], 1.2], 2, [2.1, [2.1.1]]]
  def tree
    tables = []
    table = []
    n_ords = ordinals.length + 1
    contents.each do |casebook|
      if casebook.ordinals.length > n_ords
        tables.push table.push(table = [])
      elsif casebook.ordinals.length < n_ords
        table = tables.pop until tables.length < casebook.ordinals.length
      end
      n_ords = casebook.ordinals.length
      table.push casebook
    end
    tables.first || table
  end
end
